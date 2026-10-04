import '../../../widgets/glass_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/gradient_button.dart';

import '../../../services/supabase_service.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'upi';
  bool _isProcessing = false;

  final TextEditingController _couponController = TextEditingController();
  Map<String, dynamic>? _appliedCoupon;
  String? _couponError;
  double _couponDiscountAmount = 0.0;

  double _repeatDiscountPercent = 5.0; // default 5% from app_settings
  bool _isRepeatBooking = true; // repeat booking simulation/check
  double _baseGuideTotal = 7500.0;
  double _platformFee = 300.0;

  @override
  void initState() {
    super.initState();
    _fetchLoyaltySettings();
  }

  Future<void> _fetchLoyaltySettings() async {
    try {
      final res = await SupabaseService.instance.client
          ?.from('app_settings')
          .select('value')
          .eq('key', 'loyalty_discounts')
          .maybeSingle();
      if (res != null && res['value'] is Map) {
        final val = res['value'];
        if (mounted && val['repeat_booking_discount_percent'] != null) {
          setState(() {
            _repeatDiscountPercent = (val['repeat_booking_discount_percent'] as num).toDouble();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _couponError = null;
    });

    try {
      final res = await SupabaseService.instance.client
          ?.from('coupons')
          .select()
          .eq('code', code)
          .eq('is_active', true)
          .maybeSingle();

      if (res != null) {
        final type = res['discount_type'] ?? 'percent';
        final val = (res['discount_value'] as num?)?.toDouble() ?? 0.0;
        final minSpend = (res['min_spend'] as num?)?.toDouble() ?? 0.0;

        if (_baseGuideTotal < minSpend) {
          setState(() {
            _couponError = 'Minimum spend of ₹${minSpend.toInt()} required for code $code';
          });
          return;
        }

        double calcDiscount = 0.0;
        if (type == 'percent') {
          calcDiscount = (_baseGuideTotal * val) / 100.0;
        } else {
          calcDiscount = val;
        }

        setState(() {
          _appliedCoupon = res;
          _couponDiscountAmount = calcDiscount;
          _couponError = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Coupon "$code" applied! Saved ₹${calcDiscount.toInt()}'),
              backgroundColor: AppTheme.softGreen,
            ),
          );
        }
      } else if (code.startsWith('REF-')) {
        // Referral code 10% discount fallback
        final calcDiscount = (_baseGuideTotal * 10.0) / 100.0;
        setState(() {
          _appliedCoupon = {
            'code': code,
            'description': '10% Referral Discount Applied',
          };
          _couponDiscountAmount = calcDiscount;
          _couponError = null;
        });
      } else {
        setState(() {
          _couponError = 'Invalid or expired promo code';
        });
      }
    } catch (e) {
      setState(() {
        _couponError = 'Failed to validate code';
      });
    }
  }

  double get _repeatDiscountAmount {
    if (!_isRepeatBooking) return 0.0;
    return (_baseGuideTotal * _repeatDiscountPercent) / 100.0;
  }

  double get _finalTotal {
    final total = _baseGuideTotal + _platformFee - _repeatDiscountAmount - _couponDiscountAmount;
    return total < 0 ? 0.0 : total;
  }

  void _handlePayment() async {
    setState(() => _isProcessing = true);
    final now = DateTime.now();
    try {
      await SupabaseService.instance.createBooking(
        agentId: 'a1b2c3d4-0000-0000-0000-000000000001',
        destination: 'Bali, Indonesia',
        startDate: now.add(const Duration(days: 3)),
        endDate: now.add(const Duration(days: 6)),
        totalPrice: _finalTotal,
      );
    } catch (_) {}
    if (mounted) {
      setState(() => _isProcessing = false);
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.softGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.check, color: AppTheme.softGreen, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'Booking Confirmed!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.charcoalText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your tour guide Wayan Sudarsa has been reserved for ₹${_finalTotal.toInt()}. Check your email for full receipt details.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.greyText, fontSize: 14),
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Back to Home',
              style: GradientButtonStyle.primaryCoral,
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/traveller_home', (route) => false);
              },
            ),
          ],
        ),
      ),
    );
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(),
                        const SizedBox(height: 20),
                        _buildCouponSection(),
                        const SizedBox(height: 24),
                        Text(
                          'Payment Method',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppTheme.textDark,
                                fontSize: 18,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildPaymentMethods(),
                      ],
                    ),
                  ),
                ),
                _buildPayButton(context),
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
            'Checkout & Payment',
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

  Widget _buildCouponSection() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.tag, color: AppTheme.coralGold, size: 18),
              SizedBox(width: 8),
              Text(
                'Apply Promo Code or Referral Code',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.charcoalText),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  textAllCaps: true,
                  decoration: InputDecoration(
                    hintText: 'e.g. GUIDE25 or REF-ALEX-8821',
                    hintStyle: const TextStyle(fontSize: 12, color: AppTheme.greyText),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.oceanTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: _applyCoupon,
                child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ),
          if (_couponError != null) ...[
            const SizedBox(height: 6),
            Text(_couponError!, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
          if (_appliedCoupon != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.softGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🎉 Code ${_appliedCoupon!['code']} Applied! (-₹${_couponDiscountAmount.toInt()})',
                    style: const TextStyle(color: AppTheme.softGreen, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _appliedCoupon = null;
                        _couponDiscountAmount = 0.0;
                        _couponController.clear();
                      });
                    },
                    child: const Icon(LucideIcons.x, size: 16, color: AppTheme.softGreen),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Summary',
            style: TextStyle(
              color: AppTheme.charcoalText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _buildRow('Guide Name', 'Wayan Sudarsa'),
          _buildRow('Dates', 'Oct 15 - Oct 17 (3 Days)'),
          _buildRow('Daily Rate', '₹2,500 / day'),
          const Divider(height: 24),
          _buildRow('Base Guide Fee', '₹${_baseGuideTotal.toInt()}'),
          _buildRow('Platform Fee', '₹${_platformFee.toInt()}'),
          if (_isRepeatBooking)
            _buildRow('Repeat Guide Discount (${_repeatDiscountPercent.toInt()}%)', '-₹${_repeatDiscountAmount.toInt()}', isDiscount: true),
          if (_couponDiscountAmount > 0)
            _buildRow('Promo Code Discount', '-₹${_couponDiscountAmount.toInt()}', isDiscount: true),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(
                '₹${_finalTotal.toInt()}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.oceanTeal,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDiscount ? AppTheme.softGreen : AppTheme.greyText, fontSize: 14, fontWeight: isDiscount ? FontWeight.w700 : FontWeight.w400)),
          Text(value, style: TextStyle(color: isDiscount ? AppTheme.softGreen : AppTheme.charcoalText, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    final methods = [
      {'id': 'upi', 'name': 'GPay / PhonePe / UPI', 'icon': LucideIcons.qrCode},
      {'id': 'card', 'name': 'Credit / Debit Card', 'icon': LucideIcons.creditCard},
      {'id': 'netbanking', 'name': 'Net Banking', 'icon': LucideIcons.building2},
    ];

    return Column(
      children: methods.map((method) {
        final isSelected = _selectedMethod == method['id'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => setState(() => _selectedMethod = method['id'] as String),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Icon(method['icon'] as IconData, color: isSelected ? AppTheme.coralGold : AppTheme.oceanTeal, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      method['name'] as String,
                      style: const TextStyle(color: AppTheme.charcoalText, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  Radio<String>(
                    value: method['id'] as String,
                    groupValue: _selectedMethod,
                    activeColor: AppTheme.coralGold,
                    onChanged: (val) => setState(() => _selectedMethod = val!),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPayButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.textDark,
        boxShadow: AppTheme.softShadow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: GradientButton(
        text: 'Pay ₹${_finalTotal.toInt()} Securely',
        isLoading: _isProcessing,
        style: GradientButtonStyle.primaryCoral,
        onPressed: _handlePayment,
      ),
    );
  }
}
