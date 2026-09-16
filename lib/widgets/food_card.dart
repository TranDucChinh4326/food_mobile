import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/flash_sale.dart';
import '../models/food_item.dart';
import 'app_image.dart';
import 'neon_spin_border.dart';
import 'skeleton_loader.dart';

class FoodCard extends StatelessWidget {
  const FoodCard({
    super.key,
    required this.food,
    required this.isFavorite,
    required this.onFavorite,
    required this.onAdd,
    this.onTap,
    this.flashSale,
    this.isFlashSaleTimeActive = true,
  });

  final FoodItem food;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onAdd;
  final VoidCallback? onTap;
  final FlashSaleItem? flashSale;
  final bool isFlashSaleTimeActive;

  String _price(int value) {
    final digits = value.toString();
    final chunks = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      chunks.insert(0, digits.substring((end - 3).clamp(0, end), end));
    }
    return '${chunks.join('.')}đ';
  }

  @override
  Widget build(BuildContext context) {
    final isExplicitFlashSale =
        flashSale != null &&
        flashSale!.salePrice > 0 &&
        flashSale!.salePrice <
            (food.price > 0 ? food.price : flashSale!.originalPrice);

    final effectivePrice = isExplicitFlashSale
        ? flashSale!.salePrice
        : food.price;
    final int? originalPrice = isExplicitFlashSale
        ? (flashSale!.originalPrice > 0
              ? flashSale!.originalPrice
              : (food.oldPrice ?? food.price))
        : food.oldPrice;

    final hasDiscount = originalPrice != null && originalPrice > effectivePrice;
    final discountPercent = hasDiscount
        ? (((originalPrice - effectivePrice) / originalPrice) * 100).round()
        : 0;

    // Khi đến thời gian Flash Sale:
    // TẤT CẢ các món sale (món nằm trong chiến dịch Flash Sale HOẶC món có giảm giá) đều kích hoạt hiệu ứng Neon Laser xoay 360 độ!
    final showNeonSpin =
        isFlashSaleTimeActive && (isExplicitFlashSale || hasDiscount);

    final cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: showNeonSpin
              ? Colors.transparent
              : AppColors.line.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: showNeonSpin
                ? const Color(0xFFFF007F).withValues(alpha: 0.15)
                : const Color(0xFF4E2D19).withValues(alpha: 0.05),
            blurRadius: showNeonSpin ? 14 : 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.32,
                    child: AppImage(
                      source: food.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.soft,
                        child: Center(
                          child: Icon(
                            Icons.restaurant,
                            size: 38,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const ImageShimmerSkeleton();
                      },
                    ),
                  ),
                  if (showNeonSpin)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF007F), Color(0xFFFF5500)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF007F)
                                  .withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '🔥 SALE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                            if (discountPercent > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '-$discountPercent%',
                                style: const TextStyle(
                                  color: Color(0xFFFFEA00),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else if (hasDiscount)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF3D00), Color(0xFFFF6E40)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '-$discountPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _FavoriteButton(
                      isFavorite: isFavorite,
                      onToggle: onFavorite,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: showNeonSpin
                                    ? const Color(0xFFFF007F)
                                          .withValues(alpha: 0.1)
                                    : AppColors.orange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                food.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: showNeonSpin
                                      ? const Color(0xFFFF0055)
                                      : AppColors.orange,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          if (showNeonSpin) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3D00),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'FLASH',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        food.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.amber,
                            size: 16,
                          ),
                          Text(
                            ' ${food.rating} ',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '• ${food.sold} đã bán',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasDiscount)
                                  Text(
                                    _price(originalPrice),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Text(
                                      _price(effectivePrice),
                                      style: TextStyle(
                                        color: showNeonSpin
                                            ? const Color(0xFFE53935)
                                            : AppColors.orangeDark,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (showNeonSpin) ...[
                                      const SizedBox(width: 3),
                                      const Text(
                                        '⚡',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: showNeonSpin
                                ? const Color(0xFFFF5500)
                                : AppColors.orange,
                            borderRadius: BorderRadius.circular(8),
                            elevation: 1,
                            child: InkWell(
                              onTap: onAdd,
                              borderRadius: BorderRadius.circular(8),
                              child: const SizedBox(
                                width: 32,
                                height: 32,
                                child: Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 17,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (showNeonSpin) {
      return NeonSpinBorder(
        borderRadius: 14,
        borderWidth: 2.2,
        glow: true,
        child: cardContent,
      );
    }

    return cardContent;
  }
}

class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton({required this.isFavorite, required this.onToggle});

  final bool isFavorite;
  final VoidCallback onToggle;

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.45,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.45,
          end: 0.85,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.85,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_ctrl);
  }

  @override
  void didUpdateWidget(_FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: IconButton(
          onPressed: widget.onToggle,
          tooltip: widget.isFavorite ? 'Bỏ yêu thích' : 'Yêu thích',
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
          iconSize: 19,
          icon: Icon(
            widget.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: widget.isFavorite
                ? const Color(0xFFE53935)
                : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
