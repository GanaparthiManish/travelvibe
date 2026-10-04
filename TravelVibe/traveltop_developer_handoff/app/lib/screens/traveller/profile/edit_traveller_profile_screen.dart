import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/app_network_image.dart';

class EditTravellerProfileScreen extends StatefulWidget {
  const EditTravellerProfileScreen({super.key});

  @override
  State<EditTravellerProfileScreen> createState() => _EditTravellerProfileScreenState();
}

class _EditTravellerProfileScreenState extends State<EditTravellerProfileScreen> {
  final _supabase = Supabase.instance.client;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyController = TextEditingController();
  String? _photoUrl;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _saveError;

  String? _nameError;
  String? _emailError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final res = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        _nameController.text = res?['full_name'] ?? user.userMetadata?['full_name'] ?? '';
        _emailController.text = res?['email'] ?? user.email ?? '';
        _phoneController.text = res?['phone'] ?? user.phone ?? '';
        _emergencyController.text = res?['emergency_contact'] ?? '';
        _photoUrl = res?['photo_url'];
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _validateForm() {
    setState(() {
      _nameError = null;
      _emailError = null;
      _phoneError = null;
      _saveError = null;
    });

    bool isValid = true;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _nameError = 'Full name cannot be empty';
      isValid = false;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isNotEmpty && !emailRegex.hasMatch(email)) {
      _emailError = 'Please enter a valid email address';
      isValid = false;
    }

    final phoneRegex = RegExp(r'^\+?[0-9\s-]{7,15}$');
    if (phone.isNotEmpty && !phoneRegex.hasMatch(phone)) {
      _phoneError = 'Please enter a valid phone number';
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  Future<void> _saveProfile() async {
    if (!_validateForm()) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user found.');

      final newEmail = _emailController.text.trim();
      final newName = _nameController.text.trim();
      final newPhone = _phoneController.text.trim();
      final newEmergency = _emergencyController.text.trim();

      // Upsert Supabase Profiles table record (creates if missing, updates if exists)
      final profileData = <String, dynamic>{
        'id': user.id,
        'full_name': newName,
        'phone': newPhone,
        'emergency_contact': newEmergency,
        'role': 'traveller',
      };
      if (_photoUrl != null) {
        profileData['photo_url'] = _photoUrl;
      }

      await _supabase.from('profiles').upsert(profileData);

      // Update Supabase Auth user metadata & email
      final userAttributes = UserAttributes(
        email: (newEmail.isNotEmpty && newEmail != user.email) ? newEmail : null,
        data: {'full_name': newName},
      );
      await _supabase.auth.updateUser(userAttributes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppTheme.textDark),
                SizedBox(width: 10),
                Text('Profile updated successfully!'),
              ],
            ),
            backgroundColor: AppTheme.teal,
          ),
        );
        Navigator.pop(context, true); // Return true to trigger refresh in Settings
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        setState(() {
          _saveError = 'Failed to save: ${e.toString().replaceAll('PostgrestException', '').replaceAll('AuthException', '').trim()}';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                if (_saveError != null) _buildSaveErrorBanner(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.textDark))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _buildPhotoUploadHeader(),
                              const SizedBox(height: 24),
                              CustomTextField(
                                controller: _nameController,
                                hintText: 'Full Name',
                                prefixIcon: Icons.person_outline,
                                errorText: _nameError,
                              ),
                              const SizedBox(height: 14),
                              CustomTextField(
                                controller: _emailController,
                                hintText: 'Email Address',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                errorText: _emailError,
                              ),
                              const SizedBox(height: 14),
                              CustomTextField(
                                controller: _phoneController,
                                hintText: 'Phone Number',
                                prefixIcon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                errorText: _phoneError,
                              ),
                              const SizedBox(height: 14),
                              CustomTextField(
                                controller: _emergencyController,
                                hintText: 'Emergency Contact (Safety)',
                                prefixIcon: Icons.shield_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 90),
                            ],
                          ),
                        ),
                ),
                _buildStickySaveButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.textDark.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.textDark.withValues(alpha: 0.3), width: 1.2),
                  ),
                  child: const Icon(Icons.arrow_back, color: AppTheme.textDark, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Edit Profile',
            style: TextStyle(
              color: AppTheme.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: Color(0x55000000), blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.coral,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.textDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _saveError!,
              style: const TextStyle(color: AppTheme.textDark, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoUploadHeader() {
    final fullName = _nameController.text.trim();
    final initials = fullName.isNotEmpty
        ? fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase()
        : 'AT';

    return Center(
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: _photoUrl != null && _photoUrl!.isNotEmpty
                ? AppNetworkImage(
                    imageUrl: _photoUrl!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 100,
                    height: 100,
                    color: AppTheme.teal,
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: AppTheme.textDark,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppTheme.coralGold,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_outlined, color: AppTheme.textDark, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickySaveButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: AppTheme.softShadow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: GradientButton(
        text: 'SAVE CHANGES',
        isLoading: _isSaving,
        style: GradientButtonStyle.primaryCoral,
        onPressed: _saveProfile,
      ),
    );
  }
}
