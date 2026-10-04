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

  void _handlePayment() async {
    setState(() => _isProcessing = true);
    final now = DateTime.now();
    try {
      await SupabaseService.instance.createBooking(
        agentId: 'a1b2c3d4-0000-0000-0000-000000000001',
        destination: 'Bali, Indonesia',
        startDate: now.add(const Duration(days: 3)),
        endDate: now.add(const Duration(days: 6)),
        totalPrice: 7800.0,
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
            const Text(
              'Your tour guide Wayan Sudarsa has been reserved. Check your email for full receipt details.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.greyText, fontSize: 14),
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
          _buildRow('Subtotal', '₹7,500'),
          _buildRow('Platform Fee', '₹300'),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(
                '₹7,800',
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

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.greyText, fontSize: 14)),
          Text(value, style: const TextStyle(color: AppTheme.charcoalText, fontWeight: FontWeight.w700, fontSize: 14)),
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
        text: 'Pay ₹7,800 Securely',
        isLoading: _isProcessing,
        style: GradientButtonStyle.primaryCoral,
        onPressed: _handlePayment,
      ),
    );
  }
}
