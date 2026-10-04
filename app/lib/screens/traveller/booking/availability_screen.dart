import '../../../widgets/glass_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/gradient_button.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  void _onDaySelected(DateTime date) {
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = date;
        _endDate = null;
      } else if (_startDate != null && _endDate == null) {
        if (date.isAfter(_startDate!)) {
          _endDate = date;
        } else {
          _startDate = date;
        }
      }
    });
  }

  int get _daysSelected {
    if (_startDate != null && _endDate != null) {
      return _endDate!.difference(_startDate!).inDays + 1;
    } else if (_startDate != null) {
      return 1;
    }
    return 0;
  }

  int get _totalPrice => _daysSelected * 2500;

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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCalendarCard(),
                        const SizedBox(height: 20),
                        _buildSummaryCard(),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(context),
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
                  child: Icon(LucideIcons.arrowLeft, color: AppTheme.textDark, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Select Booking Dates',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(LucideIcons.chevronLeft, color: AppTheme.charcoalText),
              Text(
                'October 2026',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.charcoalText,
                      fontSize: 18,
                    ),
              ),
              const Icon(LucideIcons.chevronRight, color: AppTheme.charcoalText),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
              return Text(
                day,
                style: const TextStyle(
                  color: AppTheme.greyText,
                  fontWeight: FontWeight.w800,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 31,
            itemBuilder: (context, index) {
              final date = DateTime(2026, 10, index + 1);
              bool isSelected = (_startDate != null && date.isAtSameMomentAs(_startDate!)) ||
                  (_endDate != null && date.isAtSameMomentAs(_endDate!));
              bool isInRange = _startDate != null &&
                  _endDate != null &&
                  date.isAfter(_startDate!) &&
                  date.isBefore(_endDate!);

              // Muted Red for fully booked days (e.g., Oct 5, Oct 12)
              bool isBooked = (index + 1) == 5 || (index + 1) == 12;

              Color bgColor = AppTheme.softGreen.withValues(alpha: 0.15); // Available default
              Color textColor = AppTheme.charcoalText;

              if (isBooked) {
                bgColor = AppTheme.mutedRed.withValues(alpha: 0.2);
                textColor = AppTheme.mutedRed;
              } else if (isSelected) {
                bgColor = AppTheme.coralGold;
                textColor = Colors.white;
              } else if (isInRange) {
                bgColor = AppTheme.coralGold.withValues(alpha: 0.35);
                textColor = AppTheme.charcoalText;
              }

              Widget cell = AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: AppTheme.coralGold, width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              );

              if (isInRange) {
                cell = cell
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(duration: 1500.ms, color: AppTheme.textDark.withValues(alpha: 0.4));
              } else if (!isSelected && !isBooked) {
                cell = cell.animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                      begin: const Offset(0.96, 0.96),
                      end: const Offset(1.0, 1.0),
                      duration: 2.seconds,
                    );
              }

              return GestureDetector(
                onTap: isBooked ? null : () => _onDaySelected(date),
                child: cell,
              );
            },
          ),
          const SizedBox(height: 16),

          // Legend
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LegendItem(color: AppTheme.softGreen, label: 'Available'),
              _LegendItem(color: AppTheme.coralGold, label: 'Selected'),
              _LegendItem(color: AppTheme.mutedRed, label: 'Booked'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selected Duration', style: TextStyle(color: AppTheme.greyText, fontSize: 13)),
              const SizedBox(height: 4),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: _daysSelected),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, child) {
                  return Text(
                    '$value Days',
                    style: const TextStyle(
                      color: AppTheme.charcoalText,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Total Guide Fee', style: TextStyle(color: AppTheme.greyText, fontSize: 13)),
              const SizedBox(height: 4),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: _totalPrice),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, child) {
                  return Text(
                    '₹$value',
                    style: const TextStyle(
                      color: AppTheme.oceanTeal,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.textDark,
        boxShadow: AppTheme.softShadow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: GradientButton(
        text: 'Proceed to Payment',
        style: GradientButtonStyle.primaryCoral,
        onPressed: _daysSelected == 0
            ? () {}
            : () => Navigator.pushNamed(context, '/payment'),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppTheme.greyText, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
