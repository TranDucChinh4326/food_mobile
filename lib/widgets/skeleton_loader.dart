import 'package:flutter/material.dart';

/// Shimmer gradient container that produces an animated shimmer effect
/// moving smoothly across all skeleton child widgets with warm peach/cream tones
/// matching the web's design system (#fff1e8 -> #fffaf6 -> #ffe1d1).
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFFFF0E5),
    this.highlightColor = const Color(0xFFFFFAF6),
    this.accentColor = const Color(0xFFFFDFC8),
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Color accentColor;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final dx = -1.5 + (progress * 3.0);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(dx - 1.0, -0.25),
              end: Alignment(dx + 1.0, 0.25),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.accentColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.45, 0.7, 1.0],
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A basic rounded skeleton placeholder block
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.color = const Color(0xFFFFF0E5),
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Standalone image shimmer skeleton for loading states in AppImage & FoodCard
class ImageShimmerSkeleton extends StatelessWidget {
  const ImageShimmerSkeleton({
    super.key,
    this.borderRadius = 0,
    this.width,
    this.height,
  });

  final double borderRadius;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SkeletonBox(
        borderRadius: borderRadius,
        width: width ?? double.infinity,
        height: height ?? double.infinity,
      ),
    );
  }
}

/// Skeleton for a single BestSellerCard in the horizontal strip
class BestSellerCardSkeleton extends StatelessWidget {
  const BestSellerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF6EDE5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4E2D19).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ShimmerLoading(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AspectRatio(
              aspectRatio: 1.3,
              child: SkeletonBox(borderRadius: 0),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 48, height: 11, borderRadius: 3),
                  SizedBox(height: 6),
                  SkeletonBox(width: 100, height: 13, borderRadius: 3),
                  SizedBox(height: 12),
                  SkeletonBox(width: 60, height: 14, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a single FoodCard in the 2-column food grid
class FoodCardSkeleton extends StatelessWidget {
  const FoodCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF6EDE5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4E2D19).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ShimmerLoading(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            const AspectRatio(
              aspectRatio: 1.32,
              child: SkeletonBox(borderRadius: 0),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category pill skeleton
                    const SkeletonBox(width: 55, height: 14, borderRadius: 4),
                    const SizedBox(height: 8),
                    // Title line 1
                    const SkeletonBox(
                      width: double.infinity,
                      height: 13,
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 5),
                    // Title line 2
                    const SkeletonBox(width: 80, height: 13, borderRadius: 4),
                    const Spacer(),
                    // Rating & Sold
                    const SkeletonBox(width: 85, height: 11, borderRadius: 3),
                    const SizedBox(height: 8),
                    // Price and Add button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SkeletonBox(
                          width: 65,
                          height: 16,
                          borderRadius: 4,
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0E5),
                            borderRadius: BorderRadius.circular(8),
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
    );
  }
}

/// Full home screen skeleton shimmer shown while foods are loading
class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Best Sellers Strip Skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerLoading(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 70, height: 10, borderRadius: 3),
                    SizedBox(height: 6),
                    SkeletonBox(width: 160, height: 18, borderRadius: 4),
                  ],
                ),
              ),
              const ShimmerLoading(
                child: SkeletonBox(width: 50, height: 12, borderRadius: 3),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, _) => const BestSellerCardSkeleton(),
          ),
        ),
        const SizedBox(height: 20),

        // 2. Food Section 1 Skeleton (THỰC ĐƠN)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerLoading(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 65, height: 10, borderRadius: 3),
                    SizedBox(height: 6),
                    SkeletonBox(width: 130, height: 18, borderRadius: 4),
                  ],
                ),
              ),
              const ShimmerLoading(
                child: SkeletonBox(width: 60, height: 12, borderRadius: 3),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.65,
            ),
            itemBuilder: (_, _) => const FoodCardSkeleton(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
