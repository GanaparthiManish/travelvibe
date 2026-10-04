import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

class AgentProfileEditScreen extends StatefulWidget {
  const AgentProfileEditScreen({super.key});

  @override
  State<AgentProfileEditScreen> createState() => _AgentProfileEditScreenState();
}

class _AgentProfileEditScreenState extends State<AgentProfileEditScreen> {
  final _bioController = TextEditingController();
  final _expController = TextEditingController();
  final _priceController = TextEditingController();
  final _languagesController = TextEditingController();
  final _placesController = TextEditingController();

  bool _mealsIncluded = false;
  bool _accommodationIncluded = false;
  bool _transportIncluded = false;

  List<String> _masterSpecializationTags = [
    'Wildlife Expert',
    'Photography Tours',
    'Family-Friendly',
    'Solo Traveller Safe',
    'Adventure/Trekking',
    'Cultural & Heritage',
    'Budget-Friendly',
    'Culinary & Food Walks',
    'Eco & Sustainable',
    'Bird Watching',
    'Spiritual & Temple Tours',
  ];
  List<String> _selectedSpecializationTags = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMasterTags();
    _loadAgentDetails();
    _loadAddons();
  }

  Future<void> _loadMasterTags() async {
    try {
      final res = await SupabaseService.instance.client
          .from('app_settings')
          .select('value')
          .eq('key', 'specialization_tags_master')
          .maybeSingle();
      if (res != null && res['value'] is List) {
        final list = List<String>.from(res['value']);
        if (list.isNotEmpty && mounted) {
          setState(() {
            _masterSpecializationTags = list;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadAgentDetails() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    final data = await SupabaseService.instance.getAgentDetails(user.id);
    if (!mounted) return;

    if (data != null) {
      _bioController.text = data['bio'] ?? '';
      _expController.text = (data['experience_years'] ?? 3).toString();
      _priceController.text = (data['price_per_day'] ?? 2500).toString();
      _languagesController.text = List<String>.from(data['languages'] ?? []).join(', ');
      _placesController.text = List<String>.from(data['places_covered'] ?? []).join(', ');
      _mealsIncluded = data['meals_included'] ?? false;
      _accommodationIncluded = data['accommodation_included'] ?? false;
      _transportIncluded = data['transport_included'] ?? false;
      _selectedSpecializationTags = List<String>.from(data['specialization_tags'] ?? data['specialties'] ?? []);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveChanges() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    final bio = _bioController.text.trim();
    final exp = int.tryParse(_expController.text.trim()) ?? 1;
    final price = double.tryParse(_priceController.text.trim()) ?? 2500.0;
    final langs = _languagesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final places = _placesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    setState(() => _isSaving = true);
    try {
      await SupabaseService.instance.saveAgentDetails(
        agentId: user.id,
        bio: bio,
        experienceYears: exp,
        pricePerDay: price,
        languages: langs,
        placesCovered: places,
        mealsIncluded: _mealsIncluded,
        accommodationIncluded: _accommodationIncluded,
        transportIncluded: _transportIncluded,
        specializationTags: _selectedSpecializationTags,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent profile updated!'), backgroundColor: AppTheme.kGreen),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e'), backgroundColor: AppTheme.kAccent),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resubmitVerificationDocs() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await SupabaseService.instance.submitVerificationDocs(agentId: user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documents re-submitted. Status set to Pending review.'),
          backgroundColor: AppTheme.kGreen,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/verification_pending', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resubmitting: $e'), backgroundColor: AppTheme.kAccent),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<Map<String, dynamic>> _addons = [];
  bool _loadingAddons = true;

  Future<void> _loadAddons() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    try {
      final list = await SupabaseService.instance.getAgentAddons(user.id);
      if (mounted) {
        setState(() {
          _addons = list;
          _loadingAddons = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingAddons = false);
    }
  }

  void _showAddonDialog({Map<String, dynamic>? existingAddon}) {
    final nameCtrl = TextEditingController(text: existingAddon?['name'] ?? '');
    final priceCtrl = TextEditingController(text: existingAddon != null ? existingAddon['price_per_day'].toString() : '');
    final descCtrl = TextEditingController(text: existingAddon?['description'] ?? '');
    String category = existingAddon?['category'] ?? 'accommodation';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.kPaper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    existingAddon != null ? 'Edit Service Option' : 'Add Custom Service Option',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.kInk),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              Text('Category', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.kInkMuted)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: ['accommodation', 'food', 'transport', 'other'].contains(category) ? category : 'accommodation',
                items: const [
                  DropdownMenuItem(value: 'accommodation', child: Text('🏨 Accommodation')),
                  DropdownMenuItem(value: 'food', child: Text('🍽️ Food & Meals')),
                  DropdownMenuItem(value: 'transport', child: Text('🚗 Transport / Vehicle')),
                  DropdownMenuItem(value: 'other', child: Text('🎒 Other Equipment / Service')),
                ],
                onChanged: (v) => setModalState(() => category = v ?? 'accommodation'),
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
              const SizedBox(height: 12),
              _buildTextField(nameCtrl, 'Option Name', 'e.g. 3-Star Hotel Stay or Basic Homestay'),
              const SizedBox(height: 12),
              _buildTextField(priceCtrl, 'Price Per Day (₹)', 'e.g. 1500', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _buildTextField(descCtrl, 'Description (Optional)', 'e.g. Includes breakfast, AC room, attached bath', maxLines: 2),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.kAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                  label: Text(
                    existingAddon != null ? 'Update Option' : 'Save Option',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                    if (name.isEmpty || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid option name and price/day.')),
                      );
                      return;
                    }

                    final user = SupabaseService.instance.currentUser;
                    if (user == null) return;

                    Navigator.pop(ctx);
                    setState(() => _isSaving = true);
                    try {
                      await SupabaseService.instance.saveAgentAddon(
                        agentId: user.id,
                        id: existingAddon?['id'],
                        category: category,
                        name: name,
                        pricePerDay: price,
                        description: descCtrl.text.trim(),
                      );
                      await _loadAddons();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Add-on saved successfully!'), backgroundColor: AppTheme.kGreen),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving option: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAddon(String addonId) async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await SupabaseService.instance.deleteAgentAddon(user.id, addonId);
      await _loadAddons();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Option removed.'), backgroundColor: AppTheme.kGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting option: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: const Text('Edit Agent Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveChanges,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.kAccent))
                : Text('Save', style: GoogleFonts.plusJakartaSans(color: AppTheme.kAccent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.kAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(_bioController, 'Professional Bio', 'Describe your tour guide background', maxLines: 3),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_expController, 'Experience (Years)', '5', keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField(_priceController, 'Base Guide Price / Day (₹)', '2500', keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_languagesController, 'Languages Spoken', 'English, Hindi, Malayalam'),
                  const SizedBox(height: 16),
                  _buildTextField(_placesController, 'Destinations Covered', 'Munnar, Alleppey, Goa'),
                  const SizedBox(height: 20),

                  // SPECIALIZATION TAGS SECTION (MASTER LIST FROM ADMIN)
                  Text('Specialization Tags (Select up to 4)', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.kInk)),
                  const SizedBox(height: 4),
                  Text('Choose your key guide specializations configured by admin', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.kInkMuted)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _masterSpecializationTags.map((tag) {
                      final isSelected = _selectedSpecializationTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              if (_selectedSpecializationTags.length < 4) {
                                _selectedSpecializationTags.add(tag);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('You can select a maximum of 4 specialization tags.')),
                                );
                              }
                            } else {
                              _selectedSpecializationTags.remove(tag);
                            }
                          });
                        },
                        selectedColor: AppTheme.kAccent,
                        backgroundColor: Colors.white,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.kInk,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSelected ? AppTheme.kAccent : AppTheme.kLine),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  // WHAT CAN YOU OFFER SECTION (ITEMIZED ADD-ONS)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.kLine),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('What Can You Offer?', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
                                const SizedBox(height: 2),
                                Text('Add Budget & Premium options for guests', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkMuted)),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showAddonDialog(),
                              icon: const Icon(Icons.add, size: 18, color: Colors.white),
                              label: Text('+ Add Option', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.kAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_loadingAddons)
                          const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.kAccent)))
                        else if (_addons.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.kPaper,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: AppTheme.kInkMuted, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No add-on options created yet. Tap "+ Add Option" to add Hotel Stays, Food Packages, or Transport Vehicles for travellers!',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkMuted),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _addons.length,
                            separatorBuilder: (_, _i) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final item = _addons[idx];
                              final String cat = item['category']?.toString() ?? 'other';
                              String iconStr = '🎒';
                              if (cat.contains('accommodat')) iconStr = '🏨';
                              if (cat.contains('food')) iconStr = '🍽️';
                              if (cat.contains('transport')) iconStr = '🚗';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.kPaper,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.kLine.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Text(iconStr, style: const TextStyle(fontSize: 22)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.kAccent.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  cat.toUpperCase(),
                                                  style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.kAccent),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  item['name'] ?? '',
                                                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.kInk),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if ((item['description'] ?? '').toString().isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item['description'].toString(),
                                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.kInkMuted),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            '₹${item['price_per_day']}/day',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.kGreen),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.kInkMuted),
                                      onPressed: () => _showAddonDialog(existingAddon: item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                      onPressed: () => _deleteAddon(item['id']),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text('Per-Day Rate Inclusions', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _mealsIncluded,
                    onChanged: (v) => setState(() => _mealsIncluded = v ?? false),
                    title: const Text('Meals Included'),
                    activeColor: AppTheme.kAccent,
                  ),
                  CheckboxListTile(
                    value: _accommodationIncluded,
                    onChanged: (v) => setState(() => _accommodationIncluded = v ?? false),
                    title: const Text('Accommodation Included'),
                    activeColor: AppTheme.kAccent,
                  ),
                  CheckboxListTile(
                    value: _transportIncluded,
                    onChanged: (v) => setState(() => _transportIncluded = v ?? false),
                    title: const Text('Transport Vehicle Included'),
                    activeColor: AppTheme.kAccent,
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: _resubmitVerificationDocs,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Re-upload Verification Documents'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.kInk,
                      side: const BorderSide(color: AppTheme.kLine, width: 1.5),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.kInk)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
