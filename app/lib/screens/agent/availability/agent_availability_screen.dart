import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

class AgentAvailabilityScreen extends StatefulWidget {
  const AgentAvailabilityScreen({super.key});

  @override
  State<AgentAvailabilityScreen> createState() => _AgentAvailabilityScreenState();
}

class _AgentAvailabilityScreenState extends State<AgentAvailabilityScreen> {
  StreamSubscription<List<Map<String, dynamic>>>? _availSub;
  final Map<String, bool> _availabilityMap = {}; // 'YYYY-MM-DD' -> true/false
  bool _isLoading = true;
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _subscribeAvailability();
  }

  void _subscribeAvailability() {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    _availSub = SupabaseService.instance.streamAgentAvailability(user.id).listen((list) {
      if (!mounted) return;
      final map = <String, bool>{};
      for (var item in list) {
        final dateStr = item['date']?.toString();
        if (dateStr != null) {
          map[dateStr] = (item['is_available'] ?? true) as bool;
        }
      }

      setState(() {
        _availabilityMap.clear();
        _availabilityMap.addAll(map);
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _availSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleDate(DateTime day) async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final currentVal = _availabilityMap[dateStr] ?? true;
    final newVal = !currentVal;

    setState(() {
      _availabilityMap[dateStr] = newVal;
    });

    try {
      await SupabaseService.instance.toggleAvailabilityDate(user.id, dateStr, newVal);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$dateStr marked as ${newVal ? "Available" : "Blocked/Unavailable"}'),
          duration: const Duration(milliseconds: 1000),
          backgroundColor: newVal ? AppTheme.kGreen : AppTheme.kInk,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating date: $e'), backgroundColor: AppTheme.kAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstDayOffset = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday - 1;

    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: const Text('Manage Calendar Availability'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.kAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month Selector Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                          });
                        },
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(_currentMonth),
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.kInk),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Days of week header
                  Row(
                    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map((d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.kInkSoft),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),

                  // Calendar Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: daysInMonth + firstDayOffset,
                    itemBuilder: (context, index) {
                      if (index < firstDayOffset) {
                        return const SizedBox.shrink();
                      }

                      final dayNum = index - firstDayOffset + 1;
                      final dayDate = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
                      final dateStr = DateFormat('yyyy-MM-dd').format(dayDate);
                      final isAvailable = _availabilityMap[dateStr] ?? true;

                      return GestureDetector(
                        onTap: () => _toggleDate(dayDate),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isAvailable ? AppTheme.kWhite : AppTheme.kAccentLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isAvailable ? AppTheme.kLine : AppTheme.kAccent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayNum',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isAvailable ? AppTheme.kInk : AppTheme.kAccent,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isAvailable ? AppTheme.kGreen : AppTheme.kAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Legend
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.kWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.kLine, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(
                          children: [
                            Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppTheme.kGreen, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('Available', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        Row(
                          children: [
                            Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppTheme.kAccent, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('Blocked / Unavailable', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
