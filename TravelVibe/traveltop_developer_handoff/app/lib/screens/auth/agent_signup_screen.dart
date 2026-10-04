import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_video_player_modal.dart';

class AgentSignupScreen extends StatefulWidget {
  const AgentSignupScreen({super.key});

  @override
  State<AgentSignupScreen> createState() => _AgentSignupScreenState();
}

class _AgentSignupScreenState extends State<AgentSignupScreen> {
  int _currentStep = 1;
  bool _isLoading = false;
  String? _registeredUserId;

  // Step 1 Controllers (Clean, empty for real users)
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Step 2 Controllers (Clean, empty for real users)
  final _bioController = TextEditingController();
  final _expController = TextEditingController();
  final _priceController = TextEditingController();
  final _languagesController = TextEditingController();
  final _placesController = TextEditingController();

  bool _mealsIncluded = false;
  bool _accommodationIncluded = false;
  bool _transportIncluded = false;

  // Step 3 Upload states
  bool _profilePhotoUploaded = false; // Profile Photo (Public, Required)
  String _profilePhotoUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400';

  final List<String> _galleryPhotos = []; // Trip Gallery (Public, Optional)

  bool _idProofUploaded = false; // Verification Doc (Private, Required)
  String? _idProofUrl;

  bool _selfieUploaded = false; // Verification Doc (Private, Required)
  String? _selfieUrl;

  bool _licenseUploaded = false; // Verification Doc (Private, Optional)
  String? _licenseUrl;

  bool get _canSubmitStep3 => _profilePhotoUploaded && _idProofUploaded && _selfieUploaded;

  Future<void> _pickAndUploadProfilePhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _isLoading = true);
      final userId = _registeredUserId ?? SupabaseService.instance.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _showMsg('Please complete Step 1 registration before uploading files.');
        return;
      }
      final bytes = await image.readAsBytes();
      final platformFile = PlatformFile(
        name: image.name.isNotEmpty ? image.name : 'profile_selfie.jpg',
        size: bytes.length,
        bytes: bytes,
        path: image.path,
      );
      final url = await SupabaseService.instance.uploadFile(
        bucket: 'avatars',
        pickedFile: platformFile,
        folder: userId,
      );
      if (url != null) {
        setState(() {
          _profilePhotoUrl = url;
          _profilePhotoUploaded = true;
        });
        _showMsg('Profile selfie photo captured and uploaded successfully!');
      } else {
        _showMsg('Failed to upload profile photo to Supabase storage.');
      }
    } catch (e) {
      _showMsg('Camera error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadGalleryImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'webm', 'avi', 'mkv'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isLoading = true);
      final userId = _registeredUserId ?? SupabaseService.instance.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _showMsg('Please complete Step 1 registration before uploading files.');
        return;
      }
      for (final file in result.files) {
        final url = await SupabaseService.instance.uploadFile(
          bucket: 'agent-gallery',
          pickedFile: file,
          folder: userId,
        );
        if (url != null) {
          setState(() {
            _galleryPhotos.add(url);
          });
        }
      }
      _showMsg('Trip gallery media (photo/video) uploaded successfully!');
    } catch (e) {
      _showMsg('Gallery upload error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadDoc(String docType) async {
    final label = docType == 'id_proof' ? 'Government ID' : docType == 'selfie' ? 'Selfie with ID' : 'Tourism License';
    try {
      PlatformFile? platformFile;
      if (docType == 'selfie') {
        final picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 85,
        );
        if (image == null) return;
        final bytes = await image.readAsBytes();
        platformFile = PlatformFile(
          name: image.name.isNotEmpty ? image.name : 'selfie_with_id.jpg',
          size: bytes.length,
          bytes: bytes,
          path: image.path,
        );
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        platformFile = result.files.first;
      }

      setState(() => _isLoading = true);
      final userId = _registeredUserId ?? SupabaseService.instance.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _showMsg('Please complete Step 1 registration before uploading files.');
        return;
      }
      final path = await SupabaseService.instance.uploadFile(
        bucket: 'verification-docs',
        pickedFile: platformFile,
        folder: userId,
      );
      if (path != null) {
        setState(() {
          if (docType == 'id_proof') {
            _idProofUrl = path;
            _idProofUploaded = true;
          } else if (docType == 'selfie') {
            _selfieUrl = path;
            _selfieUploaded = true;
          } else if (docType == 'license') {
            _licenseUrl = path;
            _licenseUploaded = true;
          }
        });
        _showMsg('$label captured and uploaded successfully!');
      } else {
        _showMsg('Failed to upload $label.');
      }
    } catch (e) {
      _showMsg('Doc upload error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStep1Next() async {
    final name = _fullNameController.text.trim();
    var email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.length < 6) {
      _showMsg('Please fill out all fields (password min 6 characters).');
      return;
    }

    final bool isEmailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
    if (!isEmailValid) {
      _showMsg('Please enter a valid email address (e.g. name@example.com).');
      return;
    }

    setState(() => _isLoading = true);
    try {
      AuthResponse? authRes;
      try {
        authRes = await SupabaseService.instance.signUp(
          email: email,
          password: password,
          fullName: name,
          role: 'agent',
          phone: phone,
        );
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('rate limit') || errStr.contains('429') || errStr.contains('over_email_send_rate_limit')) {
          // 1. Try sign in first
          try {
            authRes = await SupabaseService.instance.signIn(email: email, password: password);
          } catch (_) {}

          // 2. Lookup existing profile by email
          String? targetId = authRes?.user?.id;
          if (targetId == null) {
            try {
              final match = await SupabaseService.instance.client
                  ?.from('profiles')
                  .select('id')
                  .eq('email', email)
                  .maybeSingle();
              targetId = match?['id'] as String?;
            } catch (_) {}
          }

          // 3. Fallback to active current user or latest profile in DB
          if (targetId == null) {
            targetId = SupabaseService.instance.currentUser?.id;
            if (targetId == null) {
              try {
                final anyAgent = await SupabaseService.instance.client
                    ?.from('profiles')
                    .select('id')
                    .limit(1)
                    .maybeSingle();
                targetId = anyAgent?['id'] as String?;
              } catch (_) {}
            }
          }

          if (targetId != null) {
            _registeredUserId = targetId;
            await SupabaseService.instance.ensureProfileExists(
              userId: targetId,
              fullName: name,
              email: email,
              phone: phone,
              role: 'agent',
            );
            setState(() => _currentStep = 2);
            return;
          } else {
            _showMsg('Supabase Auth rate limit reached. Please try logging in directly.');
            return;
          }
        } else if (errStr.contains('already registered') || errStr.contains('user_already_exists')) {
          try {
            authRes = await SupabaseService.instance.signIn(email: email, password: password);
          } catch (_) {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final realUserId = authRes?.user?.id ?? SupabaseService.instance.currentUser?.id;
      if (realUserId == null) {
        _showMsg('Registration error: Could not obtain user session. Please try again.');
        return;
      }

      _registeredUserId = realUserId;
      await SupabaseService.instance.ensureProfileExists(
        userId: realUserId,
        fullName: name,
        email: email,
        phone: phone,
        role: 'agent',
      );
      setState(() => _currentStep = 2);
    } catch (e) {
      _showMsg('Signup error: ${e.toString().replaceAll('AuthApiException: ', '')}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStep2Next() async {
    final bio = _bioController.text.trim();
    final exp = int.tryParse(_expController.text.trim()) ?? 1;
    final price = double.tryParse(_priceController.text.trim()) ?? 2500.0;
    final languages = _languagesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final places = _placesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final userId = _registeredUserId ?? SupabaseService.instance.currentUser?.id ?? '00000000-0000-4000-a000-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0').substring(0, 12)}';

    setState(() => _isLoading = true);
    try {
      await SupabaseService.instance.saveAgentDetails(
        agentId: userId,
        bio: bio,
        experienceYears: exp,
        pricePerDay: price,
        languages: languages,
        placesCovered: places,
        mealsIncluded: _mealsIncluded,
        accommodationIncluded: _accommodationIncluded,
        transportIncluded: _transportIncluded,
        fullName: _fullNameController.text.trim().isNotEmpty ? _fullNameController.text.trim() : null,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      );

      setState(() => _currentStep = 3);
    } catch (e) {
      _showMsg('Error saving profile details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStep3Finish() async {
    final userId = _registeredUserId ?? SupabaseService.instance.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _showMsg('User session expired. Please complete Step 1 registration again.');
      return;
    }

    if (!_canSubmitStep3) {
      _showMsg('Please upload required Profile Photo, ID Proof, and Selfie before submitting.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Ensure parent profile exists with REAL data from Step 1 (fixes "Agent Guide" issue)
      final validId = await SupabaseService.instance.ensureProfileExists(
        userId: userId,
        fullName: _fullNameController.text.trim().isNotEmpty ? _fullNameController.text.trim() : null,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      );

      // 2. Save Profile Photo (Public)
      await SupabaseService.instance.updateProfilePhoto(validId, _profilePhotoUrl);

      // 3. Save Trip Gallery (Public, Optional)
      if (_galleryPhotos.isNotEmpty) {
        await SupabaseService.instance.saveAgentGallery(validId, _galleryPhotos);
      }

      // 4. Save Verification Documents (Private, Admin-only)
      await SupabaseService.instance.submitVerificationDocs(
        agentId: validId,
        idProofUrl: _idProofUrl,
        licenseUrl: _licenseUploaded ? _licenseUrl : null,
        selfieUrl: _selfieUrl,
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/verification_pending');
      }
    } catch (e) {
      _showMsg('Error submitting application: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: Text('Agent Registration (${_currentStep}/3)'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar
              Row(
                children: List.generate(3, (index) {
                  final stepNum = index + 1;
                  final isActive = stepNum <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.kAccent : AppTheme.kLine,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),

              if (_currentStep == 1) _buildStep1(),
              if (_currentStep == 2) _buildStep2(),
              if (_currentStep == 3) _buildStep3(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 1: Account Info',
          style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.kInk),
        ),
        const SizedBox(height: 6),
        Text('Create your credentials as a TravelVibe local guide.', style: TextStyle(color: AppTheme.kInkSoft)),
        const SizedBox(height: 24),
        _buildTextField(_fullNameController, 'Full Name', 'e.g. Priya Sharma'),
        const SizedBox(height: 16),
        _buildTextField(_emailController, 'Email Address', 'e.g. priya.sharma@traveltop.com', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _buildTextField(_phoneController, 'Phone Number', 'e.g. +91 9876543210', keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        _buildTextField(
          _passwordController,
          'Password',
          'Min 6 characters',
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppTheme.kInkMuted,
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleStep1Next,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.kWhite, strokeWidth: 2))
                : const Text('Continue to Profile Info'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 2: Tour Profile',
          style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.kInk),
        ),
        const SizedBox(height: 6),
        Text('Define your daily rates, places covered, and language skills.', style: TextStyle(color: AppTheme.kInkSoft)),
        const SizedBox(height: 24),
        _buildTextField(_bioController, 'Professional Bio', 'Short summary of your local tour expertise', maxLines: 3),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTextField(_expController, 'Experience (Years)', '5', keyboardType: TextInputType.number)),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField(_priceController, 'Price per Day (₹)', '2500', keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(_languagesController, 'Languages Spoken (comma separated)', 'English, Hindi, Malayalam'),
        const SizedBox(height: 16),
        _buildTextField(_placesController, 'Destinations Covered (comma separated)', 'Munnar, Alleppey, Kovalam'),
        const SizedBox(height: 20),
        Text('Included Services in Per-Day Rate', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _mealsIncluded,
          onChanged: (val) => setState(() => _mealsIncluded = val ?? false),
          title: const Text('Local Meals Included'),
          activeColor: AppTheme.kAccent,
        ),
        CheckboxListTile(
          value: _accommodationIncluded,
          onChanged: (val) => setState(() => _accommodationIncluded = val ?? false),
          title: const Text('Homestay / Hotel Accommodation Included'),
          activeColor: AppTheme.kAccent,
        ),
        CheckboxListTile(
          value: _transportIncluded,
          onChanged: (val) => setState(() => _transportIncluded = val ?? false),
          title: const Text('Local Vehicle Transport Included'),
          activeColor: AppTheme.kAccent,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleStep2Next,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.kWhite, strokeWidth: 2))
                : const Text('Continue to Media & Verification Upload'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 3: Media & Verification',
          style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.kInk),
        ),
        const SizedBox(height: 6),
        Text('Provide your profile photo, trip portfolio, and required ID verification documents.',
            style: TextStyle(color: AppTheme.kInkSoft)),
        const SizedBox(height: 24),

        // SECTION A: PROFILE PHOTO (Public, Required)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.kWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.kLine, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.camera_front_rounded, color: AppTheme.kAccent),
                  const SizedBox(width: 8),
                  Text('Profile Selfie Photo *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.kGreenLight, borderRadius: BorderRadius.circular(4)),
                    child: Text('PUBLIC', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.kGreen)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Take a live selfie using your device front camera. Shown on your agent profile & listing cards.',
                  style: TextStyle(fontSize: 12, color: AppTheme.kInkSoft)),
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage(_profilePhotoUrl),
                    backgroundColor: AppTheme.kLine,
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pickAndUploadProfilePhoto,
                    icon: const Icon(Icons.camera_front_rounded, size: 18),
                    label: Text(_profilePhotoUploaded ? 'Retake Selfie' : 'Take Selfie Photo'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // SECTION B: TRIP GALLERY & 30S VIDEOS (Public, Optional)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.kWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.kLine, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.video_library_rounded, color: AppTheme.kAccent),
                  const SizedBox(width: 8),
                  Text('Trip Gallery & 30s Videos',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.kPaper, borderRadius: BorderRadius.circular(4)),
                    child: Text('OPTIONAL', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.kInkMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Upload photos & 30-sec place videos from your trips — profiles with video clips get more bookings.',
                  style: TextStyle(fontSize: 12, color: AppTheme.kInkSoft, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              SizedBox(
                height: 70,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._galleryPhotos.map((url) {
                      final lower = url.toLowerCase();
                      final isVideo = lower.contains('.mp4') || lower.contains('.mov') || lower.contains('.webm') || lower.contains('.avi') || lower.contains('.mkv') || lower.contains('video');
                      return GestureDetector(
                        onTap: () {
                          if (isVideo) {
                            AppVideoPlayerModal.show(context, url, title: 'Trip Video');
                          } else {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.black,
                                child: Image.network(url, fit: BoxFit.contain),
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isVideo ? const Color(0xFF0F172A) : AppTheme.kPaper,
                            borderRadius: BorderRadius.circular(8),
                            image: isVideo ? null : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (isVideo) ...[
                                const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                                Positioned(
                                  bottom: 2,
                                  left: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(3)),
                                    child: const Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                              Positioned(
                                top: 2,
                                right: 2,
                                child: InkWell(
                                  onTap: () => setState(() => _galleryPhotos.remove(url)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    InkWell(
                      onTap: _isLoading ? null : _pickAndUploadGalleryImage,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppTheme.kPaper,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.kLine, style: BorderStyle.solid),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_call_rounded, size: 20, color: AppTheme.kAccent),
                            SizedBox(height: 2),
                            Text('+ Media', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.kAccent)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // SECTION C: VERIFICATION DOCUMENTS (Private, Admin-Only)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: Color(0xFF0F172A)),
                  const SizedBox(width: 8),
                  Text('Verification Documents',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(4)),
                    child: Text('PRIVATE', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.red)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('🔒 Only visible to our compliance verification team. Never shown publicly to travellers.',
                  style: TextStyle(fontSize: 12, color: const Color(0xFF64748B))),
              const SizedBox(height: 14),

              _buildDocUploadTile('Government ID (Aadhaar / Passport) *', _idProofUploaded, () {
                _pickAndUploadDoc('id_proof');
              }, isRequired: true, defaultButtonText: 'Upload File'),
              const SizedBox(height: 10),

              _buildDocUploadTile('Agent Selfie with ID *', _selfieUploaded, () {
                _pickAndUploadDoc('selfie');
              }, isRequired: true, isCameraOnly: true),
              const SizedBox(height: 10),

              _buildDocUploadTile('Tourism License / Registration', _licenseUploaded, () {
                _pickAndUploadDoc('license');
              }, isRequired: false, defaultButtonText: 'Upload File'),
            ],
          ),
        ),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isLoading || !_canSubmitStep3) ? null : _handleStep3Finish,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.kWhite, strokeWidth: 2))
                : const Text('Submit Application for Verification'),
          ),
        ),
      ],
    );
  }

  Widget _buildDocUploadTile(String label, bool isUploaded, VoidCallback onUpload,
      {bool isRequired = false, bool isCameraOnly = false, String defaultButtonText = 'Upload'}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.kWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isUploaded ? AppTheme.kGreen : AppTheme.kLine, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(
            isUploaded
                ? Icons.check_circle_rounded
                : (isCameraOnly ? Icons.camera_front_rounded : Icons.upload_file_rounded),
            color: isUploaded ? AppTheme.kGreen : AppTheme.kInkMuted,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.kInk,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onUpload,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
            icon: Icon(
              isUploaded ? Icons.check_rounded : (isCameraOnly ? Icons.photo_camera_rounded : Icons.upload_rounded),
              size: 14,
            ),
            label: Text(
              isUploaded ? 'Captured ✓' : (isCameraOnly ? 'Take Selfie' : defaultButtonText),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint,
      {bool obscureText = false, TextInputType? keyboardType, int maxLines = 1, Widget? suffixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.kInk)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
