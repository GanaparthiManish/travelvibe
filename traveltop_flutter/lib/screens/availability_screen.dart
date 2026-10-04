import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

import '../services/data_service.dart';
import 'payment_screen.dart';

class AvailabilityScreen extends StatefulWidget {
  final String agentId;
  final String agentName;
  final int pricePerDay;

  const AvailabilityScreen({
    super.key,
    required this.agentId,
    required this.agentName,
    required this.pricePerDay,
  });

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<DateTime> _blockedDates = [];
  bool _loading = true;

  // Feature 4: Group Booking Support
  int _groupSize = 1;
  final List<Map<String, TextEditingController>> _memberControllers = [];

  void _updateMemberControllers(int size) {
    while (_memberControllers.length < size - 1) {
      _memberControllers.add({
        'name': TextEditingController(),
        'phone': TextEditingController(),
      });
    }
    while (_memberControllers.length > size - 1 && _memberControllers.isNotEmpty) {
      final last = _memberControllers.removeLast();
      last['name']?.dispose();
      last['phone']?.dispose();
    }
  }

  List<Map<String, String>> _getGroupMembersList() {
    final List<Map<String, String>> list = [];
    for (final m in _memberControllers) {
      final name = m['name']?.text.trim() ?? '';
      final phone = m['phone']?.text.trim() ?? '';
      if (name.isNotEmpty || phone.isNotEmpty) {
        list.add({'name': name, 'phone': phone});
      }
    }
    return list;
  }

  @override
  void dispose() {
    for (final m in _memberControllers) {
      m['name']?.dispose();
      m['phone']?.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchAvailability();
  }

  Future<void> _fetchAvailability() async {
    setState(() => _loading = true);
    try {
      final client = SupabaseService.client;
      final res = await client
          .from('availability')
          .select('date, is_blocked')
          .eq('agent_id', widget.agentId)
          .eq('is_blocked', true);

      final dates = (res as List).map((e) => DateTime.parse(e['date'])).toList();
      if (mounted) {
        setState(() {
          _blockedDates = dates;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching availability: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _selectedDays {
    if (_startDate == null || _endDate == null) return 1;
    final diff = _endDate!.difference(_startDate!).inDays;
    return diff <= 0 ? 1 : diff + 1;
  }

  int get _totalPrice => _selectedDays * widget.pricePerDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBgColor(context),
      appBar: AppBar(
        backgroundColor: appBgColor(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kInk, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Select Dates', style: kAppBarTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking with ${widget.agentName}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select start and end dates for your trip.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: kInkSoft,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Date Pickers Cards
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 90)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _startDate = picked;
                                  if (_endDate != null && _endDate!.isBefore(_startDate!)) {
                                    _endDate = _startDate;
                                  }
                                });
                              }
                            },
                            child: ttInfoCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('START DATE', style: kStatLabel),
                                  const SizedBox(height: 6),
                                  Text(
                                    _startDate != null
                                        ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                        : 'Select Date',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final initial = _startDate ?? DateTime.now().add(const Duration(days: 1));
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: initial,
                                firstDate: initial,
                                lastDate: DateTime.now().add(const Duration(days: 90)),
                              );
                              if (picked != null) {
                                setState(() => _endDate = picked);
                              }
                            },
                            child: ttInfoCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('END DATE', style: kStatLabel),
                                  const SizedBox(height: 6),
                                  Text(
                                    _endDate != null
                                        ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                        : 'Select Date',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Feature 4: Number of Travellers Stepper
                    ttSectionH('Number of Travellers'),
                    ttInfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: kAccent.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.people_alt_rounded, color: kAccent, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Travellers',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: kInk,
                                        ),
                                      ),
                                      Text(
                                        _groupSize == 1 ? 'Solo Traveller' : 'Group of $_groupSize',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: kInkSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, color: kInkSoft),
                                    onPressed: _groupSize > 1
                                        ? () {
                                            setState(() {
                                              _groupSize--;
                                              _updateMemberControllers(_groupSize);
                                            });
                                          }
                                        : null,
                                  ),
                                  Text(
                                    '$_groupSize',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: kInk,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline_rounded, color: kAccent),
                                    onPressed: _groupSize < 15
                                        ? () {
                                            setState(() {
                                              _groupSize++;
                                              _updateMemberControllers(_groupSize);
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_groupSize > 1) ...[
                            const Divider(height: 24),
                            Text(
                              'Additional Group Members (Optional)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kInk,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (int i = 0; i < _memberControllers.length; i++) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: _memberControllers[i]['name'],
                                        decoration: InputDecoration(
                                          hintText: 'Member ${i + 2} Name',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        style: GoogleFonts.plusJakartaSans(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: _memberControllers[i]['phone'],
                                        keyboardType: TextInputType.phone,
                                        decoration: InputDecoration(
                                          hintText: 'Phone',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        style: GoogleFonts.plusJakartaSans(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Calculation breakdown
                    ttSectionH('Price Summary'),
                    ttInfoCard(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹${widget.pricePerDay} × $_selectedDays day(s)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: kInkSoft,
                                ),
                              ),
                              Text(
                                '₹$_totalPrice',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: kInk,
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 20, color: appLineColor(context)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Amount',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: kInk,
                                ),
                              ),
                              Text(
                                '₹$_totalPrice',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: kAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sticky Bottom CTA Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kWhite,
                border: Border(top: BorderSide(color: appLineColor(context), width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: ttPrimaryBtn(
                  'Proceed to Payment (₹$_totalPrice)',
                  onTap: () async {
                    if (_startDate == null || _endDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select trip dates.')),
                      );
                      return;
                    }

                    final currentUser = SupabaseService.client.auth.currentUser;
                    final prefs = await SharedPreferences.getInstance();
                    final currentEmail = currentUser?.email ?? prefs.getString('user_email') ?? '';
                    final currentName = prefs.getString('user_name') ?? currentUser?.userMetadata?['full_name'] ?? '';

                    if (currentUser != null && (currentUser.id == widget.agentId || currentEmail.toLowerCase() == widget.agentId.toLowerCase() || (currentName.isNotEmpty && currentName.toLowerCase() == widget.agentName.toLowerCase()))) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You cannot book yourself as a guide. Please select a different local guide.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentScreen(
                          agentId: widget.agentId,
                          agentName: widget.agentName,
                          startDate: _startDate!,
                          endDate: _endDate!,
                          totalAmount: _totalPrice,
                          groupSize: _groupSize,
                          groupMembers: _getGroupMembersList(),
                        ),
                      ),
                    );
                  },

                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
