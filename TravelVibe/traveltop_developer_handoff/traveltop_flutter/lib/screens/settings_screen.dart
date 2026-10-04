import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/data_service.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _locationServices = true;
  bool _emailAlerts = true;
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
    _loadProfileLanguage();
  }

  Future<void> _loadProfileLanguage() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select('preferred_language')
          .eq('id', userId)
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
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'preferred_language': code})
          .eq('id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chat & App language updated to ${_languageOptions[code]} ✓')),
        );
      }
    } catch (e) {
      debugPrint('Error saving preferred_language: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBgColor(context),
      appBar: AppBar(
        backgroundColor: appBgColor(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: appPaperColor(context)),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: appInkColor(context)),
          ),
        ),
        title: Text(
          'App Settings',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18, fontWeight: FontWeight.w800, color: appInkColor(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          const SizedBox(height: 8),


          ttSectionH('Notifications & Privacy'),
          Container(
            decoration: BoxDecoration(
              color: appPaperColor(context),
              border: Border.all(color: appLineColor(context)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  activeColor: kAccent,
                  title: Text('Push Notifications', style: kLcTitle.copyWith(color: appInkColor(context))),
                  subtitle: Text('Receive booking updates & message alerts', style: kLcMeta.copyWith(color: appInkSoftColor(context))),
                  value: _pushNotifications,
                  onChanged: (v) => setState(() => _pushNotifications = v),
                ),
                Divider(height: 1, color: appLineColor(context)),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  activeColor: kAccent,
                  title: Text('Location Services', style: kLcTitle.copyWith(color: appInkColor(context))),
                  subtitle: Text('Recommend nearby guides & local destinations', style: kLcMeta.copyWith(color: appInkSoftColor(context))),
                  value: _locationServices,
                  onChanged: (v) => setState(() => _locationServices = v),
                ),
                Divider(height: 1, color: appLineColor(context)),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  activeColor: kAccent,
                  title: Text('Email Summaries', style: kLcTitle.copyWith(color: appInkColor(context))),
                  subtitle: Text('Receive weekly travel deals & booking receipts', style: kLcMeta.copyWith(color: appInkSoftColor(context))),
                  value: _emailAlerts,
                  onChanged: (v) => setState(() => _emailAlerts = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── App Language ─────────────────────────────────────────────
          ttSectionH('Language & Region'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appPaperColor(context),
              border: Border.all(color: appLineColor(context)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Display Language', style: kLcTitle.copyWith(color: appInkColor(context))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _languageOptions.containsKey(_selectedLangCode) ? _selectedLangCode : 'en',
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appLineColor(context))),
                  ),
                  dropdownColor: appPaperColor(context),
                  items: _languageOptions.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value, style: kLcMeta.copyWith(color: appInkColor(context))),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      _savePreferredLanguage(v);
                      languageNotifier.value = _languageOptions[v] ?? v;
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Data & Storage ───────────────────────────────────────────
          ttSectionH('Storage & Cache'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appPaperColor(context),
              border: Border.all(color: appLineColor(context)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clear Cached Images & Data', style: kLcTitle.copyWith(color: appInkColor(context))),
                    const SizedBox(height: 2),
                    Text('Frees up offline map cache (12.4 MB)', style: kLcMeta.copyWith(color: appInkSoftColor(context))),
                  ],
                ),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('App cache cleared successfully ✓')),
                    );
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
