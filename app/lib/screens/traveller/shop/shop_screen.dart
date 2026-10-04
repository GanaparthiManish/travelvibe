import '../../../widgets/glass_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_network_image.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _cartCount = 2;

  final List<Map<String, dynamic>> _products = [
    {
      'name': 'Waterproof Trail Backpack 35L',
      'price': '₹3,499',
      'rating': 4.9,
      'image': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400&q=80',
      'category': 'Gear',
    },
    {
      'name': 'Insulated Thermal Flask 1L',
      'price': '₹1,299',
      'rating': 4.8,
      'image': 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=400&q=80',
      'category': 'Essentials',
    },
    {
      'name': 'Compact Camping Tent 2P',
      'price': '₹5,999',
      'rating': 5.0,
      'image': 'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=400&q=80',
      'category': 'Camping',
    },
    {
      'name': 'Noise Cancelling Headphones',
      'price': '₹4,500',
      'rating': 4.7,
      'image': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400&q=80',
      'category': 'Gadgets',
    },
  ];

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
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      return _buildProductCard(_products[index]);
                    },
                  ),
                ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
                      child: const Icon(LucideIcons.arrowLeft, color: AppTheme.textDark, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Travel Gear Shop',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Color(0x55000000), blurRadius: 8)],
                ),
              ),
            ],
          ),
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.85),
                child: IconButton(
                  icon: const Icon(LucideIcons.shoppingBag, color: AppTheme.oceanTeal),
                  onPressed: () => Navigator.pushNamed(context, '/cart_checkout'),
                ),
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppTheme.coralGold,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_cartCount',
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(imageUrl: product['image'], fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: AppTheme.coralGold, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            '${product['rating']}',
                            style: const TextStyle(color: AppTheme.textDark, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            product['name'],
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.charcoalText,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                product['price'],
                style: const TextStyle(
                  color: AppTheme.oceanTeal,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _cartCount++);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product['name']} added to cart!'),
                      backgroundColor: AppTheme.oceanTeal,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.coralGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.plus, color: AppTheme.textDark, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
