import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/data_service.dart';

class SavedAddress {
  final String id;
  final String fullName;
  final String phone;
  final String flatHouse;
  final String streetArea;
  final String city;
  final String pincode;
  final String state;
  final String type; // 'Home', 'Work', 'Other'
  bool isDefault;

  SavedAddress({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.flatHouse,
    required this.streetArea,
    required this.city,
    required this.pincode,
    required this.state,
    this.type = 'Home',
    this.isDefault = false,
  });

  String get fullFormatted => '$flatHouse, $streetArea, $city, $state - $pincode';

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'phone': phone,
        'flat_house': flatHouse,
        'street_area': streetArea,
        'city': city,
        'pincode': pincode,
        'state': state,
        'type': type,
        'is_default': isDefault,
      };

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        fullName: json['full_name'] ?? '',
        phone: json['phone'] ?? '',
        flatHouse: json['flat_house'] ?? '',
        streetArea: json['street_area'] ?? '',
        city: json['city'] ?? '',
        pincode: json['pincode'] ?? '',
        state: json['state'] ?? '',
        type: json['type'] ?? 'Home',
        isDefault: json['is_default'] ?? false,
      );
}

class SavedAddressesScreen extends StatefulWidget {
  final bool selectMode;

  const SavedAddressesScreen({super.key, this.selectMode = false});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  List<SavedAddress> _addresses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList('saved_addresses_list') ?? [];
      final List<SavedAddress> loaded = [];

      for (final str in rawList) {
        try {
          loaded.add(SavedAddress.fromJson(jsonDecode(str)));
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _addresses = loaded;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAddressesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, SavedAddress> uniqueMap = {};
    for (final a in _addresses) {
      final key = '${a.flatHouse}_${a.streetArea}_${a.pincode}'.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      uniqueMap[key] = a;
    }
    _addresses = uniqueMap.values.toList();
    final list = _addresses.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList('saved_addresses_list', list);
  }

  void _showAddEditSheet([SavedAddress? existing]) {
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final flatCtrl = TextEditingController(text: existing?.flatHouse ?? '');
    final streetCtrl = TextEditingController(text: existing?.streetArea ?? '');
    final cityCtrl = TextEditingController(text: existing?.city ?? '');
    final pinCtrl = TextEditingController(text: existing?.pincode ?? '');
    final stateCtrl = TextEditingController(text: existing?.state ?? 'Telangana');
    String type = existing?.type ?? 'Home';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      existing == null ? 'Add Delivery Address' : 'Edit Address',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Type Selector Badges
                    Row(
                      children: ['Home', 'Work', 'Other'].map((t) {
                        final isSelected = type == t;
                        return GestureDetector(
                          onTap: () => setSheetState(() => type = t),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFF7300) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              t,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    _buildField('FULL NAME', nameCtrl, 'e.g. Rahul Sharma'),
                    const SizedBox(height: 12),
                    _buildField('PHONE NUMBER', phoneCtrl, '+91 98765 43210', keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    _buildField('FLAT / HOUSE NO. / BUILDING', flatCtrl, 'Flat 402, Royal Residency'),
                    const SizedBox(height: 12),
                    _buildField('STREET / AREA / COLONY', streetCtrl, 'Jubilee Hills, Road No. 36'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildField('CITY', cityCtrl, 'Hyderabad')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('PINCODE', pinCtrl, '500033', keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildField('STATE', stateCtrl, 'Telangana'),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty ||
                              flatCtrl.text.trim().isEmpty ||
                              cityCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill in required address fields.')),
                            );
                            return;
                          }

                          final newAddr = SavedAddress(
                            id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                            fullName: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            flatHouse: flatCtrl.text.trim(),
                            streetArea: streetCtrl.text.trim(),
                            city: cityCtrl.text.trim(),
                            pincode: pinCtrl.text.trim(),
                            state: stateCtrl.text.trim(),
                            type: type,
                            isDefault: existing?.isDefault ?? (_addresses.isEmpty),
                          );

                          setState(() {
                            if (existing != null) {
                              final idx = _addresses.indexWhere((a) => a.id == existing.id);
                              if (idx != -1) _addresses[idx] = newAddr;
                            } else {
                              _addresses.add(newAddr);
                            }
                          });

                          await _saveAddressesToPrefs();
                          if (mounted) Navigator.pop(ctx);
                        },
                        child: Text(
                          'Save Delivery Address',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13.5),
            fillColor: const Color(0xFFF8FAFC),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBgColor(context),
      appBar: AppBar(
        backgroundColor: appBgColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: appInkColor(context), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.selectMode ? 'Select Address' : 'Saved Addresses',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: appInkColor(context),
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7300)))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _addresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final addr = _addresses[index];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: appPaperColor(context),
                          border: Border.all(
                            color: addr.isDefault ? const Color(0xFFFF7300) : appLineColor(context),
                            width: addr.isDefault ? 1.8 : 1,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF7300).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        addr.type.toUpperCase(),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFFF7300),
                                        ),
                                      ),
                                    ),
                                    if (addr.isDefault) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        'DEFAULT',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                                      onPressed: () => _showAddEditSheet(addr),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                      onPressed: () async {
                                        setState(() => _addresses.removeAt(index));
                                        await _saveAddressesToPrefs();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              addr.fullName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: appInkColor(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              addr.fullFormatted,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: appInkSoftColor(context),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Phone: ${addr.phone}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: appInkSoftColor(context),
                              ),
                            ),
                            if (widget.selectMode) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF7300),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context, addr);
                                  },
                                  child: Text(
                                    'Deliver to this Address',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _showAddEditSheet(),
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: Text(
                        'Add New Address',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
