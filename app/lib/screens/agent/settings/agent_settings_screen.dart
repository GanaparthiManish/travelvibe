import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/agent_avatar.dart';

class AgentSettingsScreen extends StatefulWidget {
  const AgentSettingsScreen({super.key});

  @override
  State<AgentSettingsScreen> createState() => _AgentSettingsScreenState();
}

class _AgentSettingsScreenState extends State<AgentSettingsScreen> {
  Map<String, dynamic>? _agentProfile;
  bool _isLoading = true;
  bool _pushNotifications = true;
  bool _autoAcceptBookings = false;
  String _selectedLangCode = 'en';

  static const Map<String, String> _languageOptions = {
    'en': 'English',
    'hi': 'Hindi (हिंदी)',
    'ml': 'Malayalam (മലയാളം)',
    'ta': 'Tamil (தமிழ்)',
    'te': 'Telugu (తెలుగు)',
    'kn': 'Kannada (കന്നഡ)',
    'bn': 'Bengali (বাংলা)',
    'mr': 'Marathi (मराठी)',
    'fr': 'French (Français)',
    'de': 'German (Deutsch)',
    'es': 'Spanish (Español)',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadProfileLanguage();
  }

  Future<void> _loadProfileLanguage() async {
    final agentId = SupabaseService.instance.activeAgentId ?? SupabaseService.instance.currentUser?.id;
    if (agentId == null) return;
    try {
      final data = await SupabaseService.instance.client
          ?.from('profiles')
          .select('preferred_language')
          .eq('id', agentId)
          .maybeSingle();
      if (data != null && data['preferred_language'] != null) {
        if (mounted) {
          setState(() {
            _selectedLangCode = data['preferred_language'] as String;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _savePreferredLanguage(String code) async {
    setState(() => _selectedLangCode = code);
    final agentId = SupabaseService.instance.activeAgentId ?? SupabaseService.instance.currentUser?.id;
    if (agentId == null) return;
    try {
      await SupabaseService.instance.client
          ?.from('profiles')
          .update({'preferred_language': code})
          .eq('id', agentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chat language updated to ${_languageOptions[code]} ✓'), backgroundColor: AppTheme.kGreen),
        );
      }
    } catch (e) {
      debugPrint('Error saving preferred_language: $e');
    }
  }

  Future<void> _loadProfile() async {
    final agentId = SupabaseService.instance.activeAgentId ?? SupabaseService.instance.currentUser?.id;
    if (agentId == null) {
      if (!mounted) return;
      setState(() {
        _agentProfile = null;
        _isLoading = false;
      });
      return;
    }

    var data = await SupabaseService.instance.getAgentDetails(agentId);

    // Fallback: fetch directly from profiles if agent_details doesn't exist
    if (data == null) {
      try {
        final profileRow = await SupabaseService.instance.client
            ?.from('profiles')
            .select('id, full_name, email, phone, photo_url')
            .eq('id', agentId)
            .maybeSingle();
        if (profileRow != null) {
          data = {'profiles': profileRow};
        }
      } catch (e) {
        debugPrint('Settings profile fallback error: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      _agentProfile = data;
      _isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out of TravelVibe?'),
        content: const Text('Are you sure you want to log out of your local agent account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.kAccent),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await SupabaseService.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _agentProfile?['profiles']?['full_name'] as String? ?? _agentProfile?['full_name'] as String? ?? '';
    final email = _agentProfile?['profiles']?['email'] as String? ?? _agentProfile?['email'] as String? ?? '';
    final photoUrl = _agentProfile?['profiles']?['photo_url'] as String? ?? _agentProfile?['photo_url'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: Text('Agent Settings', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.kAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Card Link
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/agent_profile_edit'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.kWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.kLine, width: 1.5),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Row(
                        children: [
                          AgentAvatar(name: name, photoUrl: photoUrl, radius: 26),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
                                Text(email, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppTheme.kInkMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Preferences & Toggles
                  Text('Language & Preferences', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.kWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.kLine, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Preferred Chat & Display Language', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.kInk)),
                        Text('Messages will auto-translate into this language for you', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.kInkSoft)),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _languageOptions.containsKey(_selectedLangCode) ? _selectedLangCode : 'en',
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.kLine)),
                          ),
                          items: _languageOptions.entries
                              .map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.kInk)),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              _savePreferredLanguage(v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.kWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.kLine, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _pushNotifications,
                          onChanged: (v) => setState(() => _pushNotifications = v),
                          title: Text('Push Notifications', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
                          subtitle: Text('Receive instant alerts for tour requests', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft)),
                          activeThumbColor: AppTheme.kAccent,
                        ),
                        const Divider(height: 1, color: AppTheme.kLine),
                        SwitchListTile(
                          value: _autoAcceptBookings,
                          onChanged: (v) => setState(() => _autoAcceptBookings = v),
                          title: Text('Auto-Accept Instant Bookings', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
                          subtitle: Text('Automatically confirm dates matching open availability', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft)),
                          activeThumbColor: AppTheme.kAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Management Links
                  Text('Account & Support', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.kWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.kLine, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        _buildTile(Icons.edit_calendar_rounded, 'Manage Availability Calendar', () {
                          Navigator.pushNamed(context, '/agent_availability');
                        }),
                        const Divider(height: 1, color: AppTheme.kLine),
                        _buildTile(Icons.help_outline_rounded, 'Help & Support / Report Safety Issue', () {
                          Navigator.pushNamed(context, '/help_support');
                        }),
                        const Divider(height: 1, color: AppTheme.kLine),
                        _buildTile(Icons.privacy_tip_outlined, 'Privacy Policy & Terms', () {
                          Navigator.pushNamed(context, '/privacy_policy');
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout_rounded, color: AppTheme.kAccent),
                      label: Text('Log Out', style: GoogleFonts.plusJakartaSans(color: AppTheme.kAccent, fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.kAccent, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.kInk, size: 20),
      title: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.kInk)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.kInkMuted),
      onTap: onTap,
    );
  }
}
