import '../../../widgets/glass_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/app_network_image.dart';

import 'package:provider/provider.dart';
import '../../../providers/app_state_provider.dart';
import '../../../services/supabase_service.dart';

class CartCheckoutScreen extends StatefulWidget {
  const CartCheckoutScreen({super.key});

  @override
  State<CartCheckoutScreen> createState() => _CartCheckoutScreenState();
}

class _CartCheckoutScreenState extends State<CartCheckoutScreen> {
  bool _isPlacingOrder = false;

  void _handlePlaceOrder(BuildContext context, AppStateProvider cart) async {
    setState(() => _isPlacingOrder = true);
    try {
      await SupabaseService.instance.placeOrder(
        items: cart.cartItems,
        totalAmount: cart.cartSubtotal + 150,
        deliveryAddress: '22 Baker Street, London',
      );
    } catch (_) {}
    cart.clearCart();
    if (mounted) {
      setState(() => _isPlacingOrder = false);
      Navigator.pushReplacementNamed(context, '/order_tracking');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<AppStateProvider>(context);
    final items = cart.cartItems;
    final subtotal = cart.cartSubtotal.toInt();
    const deliveryFee = 150;
    final total = subtotal + deliveryFee;

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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Cart Items'),
                        const SizedBox(height: 12),
                        ...items.map((item) => _buildCartItemCard(item)),
                        const SizedBox(height: 20),
                        _buildAddressCard(),
                        const SizedBox(height: 20),
                        _buildOrderSummaryCard(subtotal, deliveryFee, total),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                ),
                _buildCheckoutButton(context, total),
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
            'Shopping Cart & Checkout',
            style: const TextStyle(
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

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(color: AppTheme.textDark, fontSize: 18, fontWeight: FontWeight.w800));
  }

  Widget _buildCartItemCard(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AppNetworkImage(imageUrl: item['image'], width: 60, height: 60, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.charcoalText)),
                  const SizedBox(height: 4),
                  Text('₹${item['price']}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.oceanTeal)),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.minusCircle, size: 18, color: AppTheme.greyText),
                  onPressed: () {
                    if (item['qty'] > 1) setState(() => item['qty']--);
                  },
                ),
                Text('${item['qty']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(
                  icon: const Icon(LucideIcons.plusCircle, size: 18, color: AppTheme.oceanTeal),
                  onPressed: () => setState(() => item['qty']++),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          Icon(LucideIcons.mapPin, color: AppTheme.oceanTeal, size: 24),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.charcoalText)),
                SizedBox(height: 2),
                Text('Flat 402, Sunset Heights, Indiranagar, Bengaluru - 560038', style: TextStyle(color: AppTheme.greyText, fontSize: 12)),
              ],
            ),
          ),
          Icon(LucideIcons.edit2, size: 16, color: AppTheme.coralGold),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(int subtotal, int deliveryFee, int total) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.charcoalText)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(color: AppTheme.greyText)),
              Text('₹$subtotal', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Express Delivery Fee', style: TextStyle(color: AppTheme.greyText)),
              Text('₹$deliveryFee', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('₹$total', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.coralGold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(BuildContext context, int total) {
    final cart = Provider.of<AppStateProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.textDark,
        boxShadow: AppTheme.softShadow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: GradientButton(
        text: _isPlacingOrder ? 'PLACING ORDER...' : 'PLACE ORDER (₹$total)',
        style: GradientButtonStyle.primaryCoral,
        onPressed: () {
          if (!_isPlacingOrder) _handlePlaceOrder(context, cart);
        },
      ),
    );
  }
}
