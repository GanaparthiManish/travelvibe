import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/data_service.dart';
import 'payment_screen.dart';
import 'chat_inquiry_screen.dart';

String _formatDate(DateTime d) {
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

class CustomizeTripScreen extends StatefulWidget {
  final String agentId;
  final String agentName;
  final String agentPhoto;
  final double basePricePerDay;
  final String destination;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final double? negotiatedPrice;

  const CustomizeTripScreen({
    super.key,
    required this.agentId,
    required this.agentName,
    required this.agentPhoto,
    required this.basePricePerDay,
    required this.destination,
    this.initialStartDate,
    this.initialEndDate,
    this.negotiatedPrice,
  });

  @override
  State<CustomizeTripScreen> createState() => _CustomizeTripScreenState();
}

class _CustomizeTripScreenState extends State<CustomizeTripScreen> {
  late DateTime _startDate;
  late DateTime _endDate;

  List<Map<String, dynamic>> _addons = [];
  bool _loadingAddons = true;

  final Map<String, Map<String, dynamic>?> _selectedCategoryOptions = {
    'accommodation': null,
    'food': null,
    'transport': null,
    'other': null,
  };

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate ?? DateTime.now().add(const Duration(days: 1));
    _endDate = widget.initialEndDate ?? DateTime.now().add(const Duration(days: 3));
    _fetchAddons();
  }

  final List<Map<String, dynamic>> _defaultPresets = const [
    {
      'id': 'preset-acc-1',
      'category': 'accommodation',
      'name': 'Local Family Homestay',
      'price_per_day': 400,
      'description': 'Cozy local family-run homestay with hot water & breakfast',
    },
    {
      'id': 'preset-acc-2',
      'category': 'accommodation',
      'name': '3-Star Heritage Hotel / Resort',
      'price_per_day': 1200,
      'description': 'Private AC room, scenic balcony view & pool access',
    },
    {
      'id': 'preset-food-1',
      'category': 'food',
      'name': 'Basic Local Meals (Breakfast & Dinner)',
      'price_per_day': 250,
      'description': 'Freshly prepared traditional local thali & beverages',
    },
    {
      'id': 'preset-food-2',
      'category': 'food',
      'name': 'All Meals + Evening Snacks & Tea',
      'price_per_day': 500,
      'description': '3 full gourmet meals daily + herbal tea & trek snacks',
    },
    {
      'id': 'preset-trans-1',
      'category': 'transport',
      'name': 'Shared Local Sightseeing Transport',
      'price_per_day': 300,
      'description': 'Shared cab/auto for local viewpoint transfers',
    },
    {
      'id': 'preset-trans-2',
      'category': 'transport',
      'name': 'Private AC SUV / Sedan Vehicle',
      'price_per_day': 800,
      'description': 'Dedicated private vehicle with local driver for full day',
    },
  ];

  Future<void> _fetchAddons() async {
    try {
      final list = await SupabaseService.getAgentAddons(widget.agentId);
      if (mounted) {
        setState(() {
          _addons = list.isNotEmpty ? list : _defaultPresets;
          _loadingAddons = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _addons = _defaultPresets;
          _loadingAddons = false;
        });
      }
    }
  }

  int get _numberOfDays {
    final diff = _endDate.difference(_startDate).inDays;
    return diff <= 0 ? 1 : diff + 1;
  }

  double get _baseTotal => widget.basePricePerDay * _numberOfDays;

  double get _addonsTotal {
    double total = 0.0;
    _selectedCategoryOptions.forEach((_, addon) {
      if (addon != null) {
        final price = (addon['price_per_day'] as num?)?.toDouble() ?? 0.0;
        total += price * _numberOfDays;
      }
    });
    return total;
  }

  double get _calculatedTotal => _baseTotal + _addonsTotal;

  double get _finalPayable => widget.negotiatedPrice ?? _calculatedTotal;

  List<Map<String, dynamic>> get _selectedAddonsList {
    final List<Map<String, dynamic>> list = [];
    _selectedCategoryOptions.forEach((cat, addon) {
      if (addon != null) {
        list.add({
          'addon_id': addon['id'],
          'name': addon['name'],
          'category': cat,
          'price_per_day': addon['price_per_day'],
        });
      }
    });
    return list;
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: kAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: kInk,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appPaperColor(context),
      appBar: AppBar(
        title: Text('Customize Your Trip', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: kInk)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kInk),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agent Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: appLineColor(context)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(
                      widget.agentPhoto.isNotEmpty
                          ? widget.agentPhoto
                          : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.agentName, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: kInk)),
                        const SizedBox(height: 2),
                        Text('Destination: ${widget.destination}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // STEP 1: DATES
            Text('1. Trip Dates', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: kInk)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDateRange,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kAccent, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: kAccent, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_formatDate(_startDate)}  ➔  ${_formatDate(_endDate)}', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: kInk)),
                          const SizedBox(height: 2),
                          Text('Duration: $_numberOfDays ${_numberOfDays == 1 ? "day" : "days"}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft)),
                        ],
                      ),
                    ),
                    Text('Change', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: kAccent)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // STEP 2: BASE SERVICE (ALWAYS INCLUDED)
            Text('2. Base Guide Service', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: kInk)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('🧭', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Local Tour Guide Service', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: kInk)),
                        const SizedBox(height: 2),
                        Text('Expert guiding, itinerary management & local support', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${widget.basePricePerDay.toInt()}/day', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: kAccent)),
                      Text('₹${_baseTotal.toInt()} total', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: kInk)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // STEP 3: OPTIONAL ADD-ONS BY CATEGORY
            Text('3. Select Optional Add-ons', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: kInk)),
            const SizedBox(height: 4),
            Text('Customize accommodation, food, and transport options offered by ${widget.agentName}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft)),
            const SizedBox(height: 14),

            if (_loadingAddons)
              const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator(color: kAccent)))
            else ...[
              _buildCategorySection('accommodation', '🏨 Accommodation Options'),
              const SizedBox(height: 16),
              _buildCategorySection('food', '🍽️ Food & Meals Options'),
              const SizedBox(height: 16),
              _buildCategorySection('transport', '🚗 Transport & Vehicle Options'),
              const SizedBox(height: 16),
              _buildCategorySection('other', '🎒 Other Services / Gear'),
            ],

            const SizedBox(height: 28),

            // CHAT WITH AGENT PRE-BOOKING BUTTON
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, color: Colors.amber, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Want a custom package or price discount?',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatInquiryScreen(
                              agentId: widget.agentId,
                              agentName: widget.agentName,
                              agentPhoto: widget.agentPhoto,
                              destination: widget.destination,
                              proposedDates: '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                              calculatedTotal: _calculatedTotal,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.forum_rounded, size: 18),
                      label: Text('Chat with ${widget.agentName} First', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber.shade900,
                        side: BorderSide(color: Colors.amber.shade700, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),

      // BOTTOM BAR WITH LIVE TOTAL & PROCEED BUTTON
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Payable ($_numberOfDays ${_numberOfDays == 1 ? "day" : "days"})', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kInkSoft)),
                    Row(
                      children: [
                        if (widget.negotiatedPrice != null) ...[
                          Text(
                            '₹${_calculatedTotal.toInt()}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, decoration: TextDecoration.lineThrough, color: kInkSoft),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          '₹${_finalPayable.toInt()}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: kAccent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                label: Text('Proceed to Book', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(
                        agentId: widget.agentId,
                        agentName: widget.agentName,
                        agentPhoto: widget.agentPhoto,
                        startDate: _startDate,
                        endDate: _endDate,
                        totalAmount: _finalPayable.toInt(),
                        basePrice: _baseTotal,
                        selectedAddons: _selectedAddonsList,
                        negotiatedPrice: widget.negotiatedPrice,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(String categoryKey, String title) {
    final categoryAddons = _addons.where((a) => (a['category']?.toString() ?? 'other').toLowerCase() == categoryKey).toList();
    final selectedAddon = _selectedCategoryOptions[categoryKey];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: appLineColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: kInk)),
          const SizedBox(height: 10),

          // Option: None
          RadioListTile<Map<String, dynamic>?>(
            value: null,
            groupValue: selectedAddon,
            onChanged: (v) => setState(() => _selectedCategoryOptions[categoryKey] = null),
            title: Text('None (Skip this category)', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kInkSoft)),
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: kAccent,
          ),

          if (categoryAddons.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text('No presets offered for this category.', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontStyle: FontStyle.italic, color: kInkSoft)),
            )
          else
            ...categoryAddons.map((item) {
              final price = (item['price_per_day'] as num?)?.toInt() ?? 0;
              return RadioListTile<Map<String, dynamic>?>(
                value: item,
                groupValue: selectedAddon,
                onChanged: (v) => setState(() => _selectedCategoryOptions[categoryKey] = v),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['name'] ?? '',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: kInk),
                      ),
                    ),
                    Text('+₹$price/day', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: kAccent)),
                  ],
                ),
                subtitle: (item['description'] ?? '').toString().isNotEmpty
                    ? Text(item['description'].toString(), style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kInkSoft))
                    : null,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: kAccent,
              );
            }),
        ],
      ),
    );
  }
}
