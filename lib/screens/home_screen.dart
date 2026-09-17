import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/auth_session.dart';
import '../models/combo_item.dart';
import '../models/flash_sale.dart';
import '../models/food_item.dart';
import '../models/food_review_item.dart';
import '../models/home_content.dart';
import '../services/notification_service.dart';
import '../widgets/announcement_marquee_ticker.dart';
import '../widgets/app_image.dart';
import '../widgets/food_card.dart';
import '../widgets/neon_spin_border.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/scroll_reveal.dart';
import 'category_screen.dart';
import 'food_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.cartCount,
    required this.foods,
    this.flashSales = const [],
    this.combos = const [],
    this.reviews = const [],
    this.categories = const [],
    this.announcements = const [],
    this.advertisements = const [],
    this.availableVoucherCount = 0,
    required this.loading,
    required this.loadError,
    required this.onRetry,
    required this.favorites,
    required this.onAddToCart,
    this.onAddComboToCart,
    required this.onToggleFavorite,
    this.onMarkAnnouncementsRead,
    this.session,
    this.onSelectTab,
  });

  final int cartCount;
  final List<FoodItem> foods;
  final List<FlashSaleCampaign> flashSales;
  final List<ComboItem> combos;
  final List<FoodReviewItem> reviews;
  final List<FoodCategory> categories;
  final List<HomeAnnouncement> announcements;
  final List<HomeAdvertisement> advertisements;
  final int availableVoucherCount;
  final bool loading;
  final String? loadError;
  final VoidCallback onRetry;
  final Set<int> favorites;
  final ValueChanged<String> onAddToCart;
  final ValueChanged<ComboItem>? onAddComboToCart;
  final ValueChanged<int> onToggleFavorite;
  final Future<void> Function(List<int>)? onMarkAnnouncementsRead;
  final AuthSession? session;
  final ValueChanged<int>? onSelectTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<String> _expandedDrawerCategories = {'Đồ ăn'};
  String _selectedCategory = 'Tất cả';
  String _query = '';
  static bool _hasShownAdPopup = false;
  final TextEditingController _searchController = TextEditingController();
  final PageController _announcementPageController = PageController();
  int _selectedReviewRating = 0; // 0 for All, or 5, 4, 3
  List<FoodItem> _topBestSellers = const [];
  final ScrollController _homeScrollController = ScrollController();

  Timer? _timer;
  Timer? _announcementTimer;
  Timer? _advertisementTimer;
  final ValueNotifier<Duration> _remainingTimeNotifier =
      ValueNotifier<Duration>(Duration.zero);
  late final AnimationController _flameAnimController;
  late final AnimationController _bellAnimController;
  late final Animation<double> _bellRotation;

  @override
  void initState() {
    super.initState();
    _updateBestSellers();
    _flameAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _bellAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _bellRotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -0.09,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -0.09,
          end: 0.09,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.09,
          end: -0.06,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -0.06,
          end: 0.04,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1.5,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.04,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1.5,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 14),
    ]).animate(_bellAnimController);

    _initCountdown();
    if (widget.advertisements.isNotEmpty) {
      _checkAndShowAdPopup();
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foods != widget.foods) {
      _updateBestSellers();
    }
    if (oldWidget.flashSales != widget.flashSales) {
      _initCountdown();
    }
    if (widget.advertisements.isNotEmpty && !_hasShownAdPopup) {
      _checkAndShowAdPopup();
    }
  }

  void _updateBestSellers() {
    final bestSellers = widget.foods.where((food) => food.sold > 0).toList()
      ..sort((a, b) => b.sold.compareTo(a.sold));
    _topBestSellers = bestSellers.take(5).toList();
  }

  void _initCountdown() {
    _timer?.cancel();
    final activeSale = widget.flashSales
        .where((s) => s.items.isNotEmpty)
        .firstOrNull;

    if (activeSale?.endsAt != null && activeSale!.endsAt!.isNotEmpty) {
      try {
        final endTime = DateTime.parse(activeSale.endsAt!.replaceAll(' ', 'T'));
        final now = DateTime.now();
        final diff = endTime.difference(now);
        _remainingTimeNotifier.value = diff.isNegative ? Duration.zero : diff;
      } catch (_) {
        _remainingTimeNotifier.value = const Duration(hours: 3, minutes: 45);
      }
    } else {
      _remainingTimeNotifier.value = const Duration(hours: 3, minutes: 45);
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingTimeNotifier.value.inSeconds > 0) {
        _remainingTimeNotifier.value =
            _remainingTimeNotifier.value - const Duration(seconds: 1);
        if (_remainingTimeNotifier.value.inSeconds == 0) {
          setState(() {});
        }
      }
    });
  }

  bool get _isFlashSaleTimeActive {
    final activeSale = widget.flashSales
        .where((s) => s.items.isNotEmpty)
        .firstOrNull;
    if (activeSale == null) return false;

    final now = DateTime.now();
    if (activeSale.startsAt != null && activeSale.startsAt!.isNotEmpty) {
      try {
        final startTime = DateTime.parse(
          activeSale.startsAt!.replaceAll(' ', 'T'),
        );
        if (now.isBefore(startTime)) return false;
      } catch (_) {}
    }
    if (activeSale.endsAt != null && activeSale.endsAt!.isNotEmpty) {
      try {
        final endTime = DateTime.parse(activeSale.endsAt!.replaceAll(' ', 'T'));
        if (now.isAfter(endTime)) return false;
      } catch (_) {}
    }
    if (_remainingTimeNotifier.value.inSeconds <= 0) {
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _announcementTimer?.cancel();
    _advertisementTimer?.cancel();
    _remainingTimeNotifier.dispose();
    _flameAnimController.dispose();
    _bellAnimController.dispose();
    _searchController.dispose();
    _announcementPageController.dispose();
    _homeScrollController.dispose();
    super.dispose();
  }

  void _showNotice(String message) {
    NotificationService.instance.showInfo('Bếp 1979', message);
  }

  void _openFoodDetail(FoodItem food) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodDetailScreen(
          food: food,
          isFavorite: widget.favorites.contains(food.id),
          onToggleFavorite: () => widget.onToggleFavorite(food.id),
          onAddToCart: (name, qty, notes, price) {
            for (var i = 0; i < qty; i++) {
              widget.onAddToCart(name);
            }
          },
          allFoods: widget.foods,
          flashSales: widget.flashSales,
        ),
      ),
    );
  }

  void _openCategoryScreen(
    String categoryName, {
    CategorySortOption initialSort = CategorySortOption.popular,
    bool initialOnlySale = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CategoryScreen(
          categoryName: categoryName,
          allFoods: widget.foods,
          categories: widget.categories,
          flashSales: widget.flashSales,
          favorites: widget.favorites,
          cartCount: widget.cartCount,
          onAddToCart: widget.onAddToCart,
          onToggleFavorite: widget.onToggleFavorite,
          initialSort: initialSort,
          initialOnlySale: initialOnlySale,
        ),
      ),
    );
  }

  FlashSaleItem? _getFlashSale(int foodId) {
    for (final campaign in widget.flashSales) {
      for (final item in campaign.items) {
        if (item.foodId == foodId) return item;
      }
    }
    return null;
  }

  FoodCard _buildFoodCard(FoodItem food) {
    return FoodCard(
      food: food,
      flashSale: _getFlashSale(food.id),
      isFlashSaleTimeActive: _isFlashSaleTimeActive,
      isFavorite: widget.favorites.contains(food.id),
      onFavorite: () => widget.onToggleFavorite(food.id),
      onAdd: () => widget.onAddToCart(food.name),
      onTap: () => _openFoodDetail(food),
    );
  }

  Widget _buildCategoryFoodSections() {
    final grouped = <String, List<FoodItem>>{};
    for (final food in widget.foods) {
      grouped.putIfAbsent(food.category, () => []).add(food);
    }

    final orderedNames = <String>[
      ...widget.categories
          .where((category) => category.isChild)
          .map((category) => category.name)
          .where(grouped.containsKey),
      ...grouped.keys.where(
        (name) => !widget.categories.any(
          (category) => category.isChild && category.name == name,
        ),
      ),
    ];

    return Column(
      children: orderedNames.map((name) {
        final items = grouped[name]!.take(4).toList();
        return ScrollReveal(
          offsetY: 22,
          child: Column(
            children: [
              _buildSectionHeading(
                kicker: 'THỰC ĐƠN',
                title: name,
                action: 'Xem tất cả',
                onAction: () => _openCategoryScreen(name),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.65,
                ),
                itemBuilder: (context, index) => _buildFoodCard(items[index]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnnouncementTicker() {
    final list = widget.announcements;
    if (list.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 36,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF241611),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4A2A1E)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.88,
                end: 1.14,
              ).animate(_flameAnimController),
              child: const Text('📢', style: TextStyle(fontSize: 14)),
            ),
          ),
          Container(width: 1, height: 16, color: const Color(0xFF4A2A1E)),
          Expanded(
            child: AnnouncementMarqueeTicker(
              announcements: list,
              onTap: _showAnnouncements,
            ),
          ),
        ],
      ),
    );
  }

  void _checkAndShowAdPopup() {
    if (_hasShownAdPopup) return;
    _hasShownAdPopup = true;

    _advertisementTimer?.cancel();
    _advertisementTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _showAdvertisementPopup();
    });
  }

  Future<void> _showAdvertisementPopup() async {
    if (!mounted) return;

    final List<Map<String, dynamic>> promoSlides = [];

    // Lấy chính xác các banner quảng cáo món mới từ database
    for (final ad in widget.advertisements) {
      if (ad.image.trim().isEmpty) continue;
      final foodId = ad.linkedFoodId;
      FoodItem? linkedFood = foodId != null
          ? widget.foods.where((f) => f.id == foodId).firstOrNull
          : null;
      if (linkedFood == null && ad.title.trim().isNotEmpty) {
        final cleanTitle = ad.title.toLowerCase().trim();
        linkedFood = widget.foods
            .where(
              (f) =>
                  cleanTitle.contains(f.name.toLowerCase().trim()) ||
                  f.name.toLowerCase().trim().contains(cleanTitle),
            )
            .firstOrNull;
      }
      promoSlides.add({
        'title': ad.title.isNotEmpty
            ? ad.title
            : (linkedFood?.name ?? 'Món Mới Bếp 1979'),
        'subtitle': (linkedFood?.description?.isNotEmpty == true)
            ? linkedFood!.description!
            : 'Món mới đặc sắc hôm nay • Chạm để xem chi tiết',
        'image': ad.image,
        'badge': '🔥 MÓN MỚI NỔI BẬT',
        'badgeColor': const Color(0xFFE53935),
        'food': linkedFood,
      });
    }

    if (promoSlides.isEmpty) return;

    int currentAdIndex = 0;
    // Tỉ lệ 0.82 để lộ mép của 2 poster trước và sau giống bìa phim Netflix/Galaxy Play
    final pageController = PageController(
      viewportFraction: promoSlides.length > 1 ? 0.82 : 0.92,
    );
    Timer? autoSlideTimer;

    if (promoSlides.length > 1) {
      autoSlideTimer = Timer.periodic(const Duration(milliseconds: 3600), (_) {
        if (!pageController.hasClients) return;
        final nextIdx = (currentAdIndex + 1) % promoSlides.length;
        pageController.animateToPage(
          nextIdx,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      });
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Ad',
      barrierColor: Colors.black.withValues(alpha: 0.82),
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (dialogCtx, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (dialogContext, _, _) {
        final screen = MediaQuery.of(dialogContext).size;
        final modalWidth = screen.width;
        final modalHeight = screen.height * 0.74;

        return Center(
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              return Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header nhỏ chỉ dẫn
                    if (promoSlides.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swipe_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Vuốt sang để xem thêm ưu đãi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    SizedBox(
                      width: modalWidth,
                      height: modalHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Carousel PageView (Hiệu ứng Coverflow dạng App xem phim)
                          Positioned.fill(
                            child: PageView.builder(
                              controller: pageController,
                              itemCount: promoSlides.length,
                              onPageChanged: (idx) {
                                setModalState(() => currentAdIndex = idx);
                              },
                              itemBuilder: (context, idx) {
                                final slide = promoSlides[idx];
                                final title = slide['title'] as String? ?? '';
                                final subtitle = slide['subtitle'] as String?;
                                final badge = slide['badge'] as String? ?? '';
                                final badgeColor =
                                    slide['badgeColor'] as Color? ??
                                    AppColors.orange;
                                final food = slide['food'] as FoodItem?;

                                return AnimatedBuilder(
                                  animation: pageController,
                                  builder: (context, child) {
                                    double scale = 1.0;
                                    double opacity = 1.0;
                                    if (pageController
                                        .position
                                        .haveDimensions) {
                                      final page =
                                          pageController.page ??
                                          currentAdIndex.toDouble();
                                      final diff = (page - idx).abs();
                                      // Poster ở giữa phóng to 1.0, hai bên thu nhỏ 0.86 và mờ nhẹ
                                      scale = (1 - (diff * 0.14)).clamp(
                                        0.86,
                                        1.0,
                                      );
                                      opacity = (1 - (diff * 0.35)).clamp(
                                        0.65,
                                        1.0,
                                      );
                                    } else {
                                      scale = idx == currentAdIndex
                                          ? 1.0
                                          : 0.88;
                                      opacity = idx == currentAdIndex
                                          ? 1.0
                                          : 0.7;
                                    }
                                    return Center(
                                      child: Transform.scale(
                                        scale: scale,
                                        child: Opacity(
                                          opacity: opacity,
                                          child: child,
                                        ),
                                      ),
                                    );
                                  },
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(dialogContext).pop();
                                      if (food != null) {
                                        _openFoodDetail(food);
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.55,
                                            ),
                                            blurRadius: 28,
                                            offset: const Offset(0, 12),
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Ảnh poster bìa tràn viền
                                          AppImage(
                                            source: slide['image'] as String,
                                            fit: BoxFit.cover,
                                          ),

                                          // Lớp phủ Gradient đen điện ảnh phía dưới
                                          Positioned.fill(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.transparent,
                                                    Colors.black.withValues(
                                                      alpha: 0.45,
                                                    ),
                                                    Colors.black.withValues(
                                                      alpha: 0.92,
                                                    ),
                                                  ],
                                                  stops: const [
                                                    0.0,
                                                    0.45,
                                                    0.7,
                                                    1.0,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Thông tin tên món và huy hiệu
                                          Positioned(
                                            left: 16,
                                            right: 16,
                                            bottom: 18,
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (badge.isNotEmpty)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 3.5,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: badgeColor,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  6,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            badge,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      10.5,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  letterSpacing:
                                                                      0.4,
                                                                ),
                                                          ),
                                                        ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        title,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16.5,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          height: 1.25,
                                                        ),
                                                      ),
                                                      if (subtitle != null &&
                                                          subtitle
                                                              .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 3,
                                                        ),
                                                        Text(
                                                          subtitle,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: 0.85,
                                                                ),
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                      if (food != null) ...[
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          _formatPrice(
                                                            food.price,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFFFFD54F,
                                                                ),
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                              ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 11,
                                                        vertical: 6.5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                          colors: [
                                                            Color(0xFFFF6D00),
                                                            Color(0xFFFF9100),
                                                          ],
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color:
                                                            const Color(
                                                              0xFFFF6D00,
                                                            ).withValues(
                                                              alpha: 0.4,
                                                            ),
                                                        blurRadius: 6,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .play_arrow_rounded,
                                                        size: 15,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        food != null
                                                            ? 'Đặt món'
                                                            : 'Xem ngay',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Nút 'X' đóng ở góc trên bên phải
                          Positioned(
                            top: 10,
                            right: 20,
                            child: GestureDetector(
                              onTap: () => Navigator.of(dialogContext).pop(),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.45,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Thanh chấm tròn chỉ số banner (Dots indicator)
                    if (promoSlides.length > 1) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(promoSlides.length, (idx) {
                          final isActive = idx == currentAdIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3.5),
                            width: isActive ? 22 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.orange
                                  : Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    autoSlideTimer?.cancel();
    pageController.dispose();
  }

  Future<void> _showAnnouncements() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Thông báo',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  itemCount: widget.announcements.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = widget.announcements[index];
                    return ListTile(
                      leading: Icon(
                        item.isRead
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        color: item.isRead ? AppColors.muted : AppColors.orange,
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: item.isRead
                              ? FontWeight.w600
                              : FontWeight.w900,
                        ),
                      ),
                      subtitle: item.content.isEmpty
                          ? null
                          : Text(item.content, maxLines: 3),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final unreadIds = widget.announcements
        .where((item) => !item.isRead)
        .map((item) => item.id)
        .toList();
    if (unreadIds.isNotEmpty) {
      try {
        await widget.onMarkAnnouncementsRead?.call(unreadIds);
      } catch (_) {
        if (mounted) _showNotice('Không thể đánh dấu thông báo đã đọc.');
      }
    }
  }

  void _showVoucherSummary() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
          child: Row(
            children: [
              const Icon(
                Icons.confirmation_num_outlined,
                color: AppColors.orange,
                size: 34,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.availableVoucherCount > 0
                      ? 'Bạn có thể nhận ${widget.availableVoucherCount} voucher đang hoạt động.'
                      : 'Hiện chưa có voucher mới để nhận.',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _normalize(String input) {
    var str = input.toLowerCase().trim();
    const vietnameseMap = {
      'à': 'a',
      'á': 'a',
      'ả': 'a',
      'ã': 'a',
      'ạ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'ặ': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ậ': 'a',
      'è': 'e',
      'é': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ẹ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ệ': 'e',
      'ì': 'i',
      'í': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ị': 'i',
      'ò': 'o',
      'ó': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ọ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ộ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ợ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ụ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ự': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'ỵ': 'y',
      'đ': 'd',
    };
    for (final entry in vietnameseMap.entries) {
      str = str.replaceAll(entry.key, entry.value);
    }
    return str;
  }

  static bool _isBanhMi(FoodItem food) {
    final normName = _normalize(food.name);
    final normCat = _normalize(food.categoryName ?? food.category);
    final slug = (food.categorySlug ?? '').toLowerCase().trim();
    return slug == 'banh-mi' ||
        slug == 'banhmi' ||
        normName.contains('banh mi') ||
        normName.contains('banh my') ||
        normCat.contains('banh mi') ||
        normCat.contains('banh my');
  }

  bool _foodMatchesCategory(FoodItem food, String selectedCategory) {
    if (selectedCategory == 'Tất cả') return true;

    final normTarget = _normalize(selectedCategory);
    final targetSlug = normTarget.replaceAll(' ', '-');

    final isTargetNoodle =
        normTarget == 'mi' ||
        normTarget == 'my' ||
        normTarget == 'mon mi' ||
        targetSlug == 'mi';

    if (isTargetNoodle) {
      if (_isBanhMi(food)) return false;

      final catObj = widget.categories
          .where((c) => c.slug == 'mi' || _normalize(c.name) == 'mi')
          .firstOrNull;
      if (catObj != null) {
        if (food.categoryId == catObj.id ||
            (food.categorySlug != null &&
                food.categorySlug!.toLowerCase() ==
                    catObj.slug.toLowerCase())) {
          return true;
        }
      }

      if (food.categorySlug?.toLowerCase() == 'mi') return true;
      if (_normalize(food.categoryName ?? '') == 'mi') return true;
      if (_normalize(food.category) == 'mi') return true;

      final noodleRegex = RegExp(
        r'(?<!banh\s)\b(mi|my)\b',
        caseSensitive: false,
      );
      return noodleRegex.hasMatch(_normalize(food.name)) ||
          noodleRegex.hasMatch(_normalize(food.categoryName ?? food.category));
    }

    final catObj = widget.categories
        .where((c) => c.slug == targetSlug || _normalize(c.name) == normTarget)
        .firstOrNull;

    if (catObj != null) {
      if (food.categoryId == catObj.id ||
          (food.categorySlug != null &&
              food.categorySlug!.toLowerCase() == catObj.slug.toLowerCase())) {
        return true;
      }
    }

    final normFoodCat = _normalize(food.categoryName ?? food.category);
    final foodSlug = (food.categorySlug ?? '').toLowerCase();

    if (foodSlug == targetSlug) return true;
    if (normFoodCat == normTarget) return true;
    if (normFoodCat.contains(normTarget)) return true;

    return false;
  }

  bool _foodMatchesSearch(FoodItem food, String query) {
    final q = query.trim();
    if (q.isEmpty) return true;

    final normQ = _normalize(q);
    final normName = _normalize(food.name);
    final normDesc = _normalize(food.description ?? '');
    final normCat = _normalize(food.categoryName ?? food.category);

    if (normQ == 'mi' || normQ == 'my' || normQ == 'mon mi') {
      if (_isBanhMi(food)) return false;
      final noodleRegex = RegExp(
        r'(?<!banh\s)\b(mi|my)\b',
        caseSensitive: false,
      );
      return noodleRegex.hasMatch(normName) ||
          noodleRegex.hasMatch(normCat) ||
          noodleRegex.hasMatch(normDesc) ||
          food.categorySlug == 'mi';
    }

    return normName.contains(normQ) ||
        normDesc.contains(normQ) ||
        normCat.contains(normQ);
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('cơm')) return Icons.rice_bowl_rounded;
    if (lower.contains('phở')) return Icons.ramen_dining_rounded;
    if (lower.contains('mì') || lower.contains('bún')) {
      return Icons.soup_kitchen_rounded;
    }
    if (lower.contains('trà')) return Icons.emoji_food_beverage_rounded;
    if (lower.contains('cà phê') || lower.contains('cafe')) {
      return Icons.coffee_rounded;
    }
    if (lower.contains('nước ép') || lower.contains('sinh tố')) {
      return Icons.blender_rounded;
    }
    if (lower.contains('nước') ||
        lower.contains('uống') ||
        lower.contains('chai')) {
      return Icons.local_drink_rounded;
    }
    if (lower.contains('burger')) return Icons.lunch_dining_rounded;
    if (lower.contains('pizza')) return Icons.local_pizza_rounded;
    if (lower.contains('gà')) return Icons.kebab_dining_rounded;
    if (lower.contains('nướng')) return Icons.local_fire_department_rounded;
    if (lower.contains('kho')) return Icons.dinner_dining_rounded;
    if (lower.contains('lẩu')) return Icons.set_meal_rounded;
    if (lower.contains('combo')) return Icons.fastfood_rounded;
    if (lower.contains('bánh') ||
        lower.contains('kẹo') ||
        lower.contains('tráng miệng')) {
      return Icons.cake_rounded;
    }
    return Icons.restaurant_menu_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.foods.where((food) {
      final matchesCategory =
          _selectedCategory == 'Tất cả' ||
          _foodMatchesCategory(food, _selectedCategory);
      return matchesCategory && _foodMatchesSearch(food, _query);
    }).toList();

    final showGroupedCatalog =
        _query.trim().isEmpty && _selectedCategory == 'Tất cả';

    final activeSale = widget.flashSales
        .where((s) => s.items.isNotEmpty)
        .firstOrNull;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFFBF8),
      drawer: _buildCategoryDrawer(),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.orange,
          backgroundColor: Colors.white,
          onRefresh: () async {
            widget.onRetry();
            await Future.delayed(const Duration(milliseconds: 600));
          },
          child: HomeScrollScope(
            scrollController: _homeScrollController,
            child: CustomScrollView(
              controller: _homeScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Header Top (with Hamburger menu on the left to open drawer)
                SliverToBoxAdapter(child: _buildHeader()),

                // 2. Search & Filter Bar
                SliverToBoxAdapter(child: _buildSearch()),

                if (_query.isEmpty && widget.announcements.isNotEmpty)
                  SliverToBoxAdapter(child: _buildAnnouncementTicker()),

                // 3. Real Flash Sale Section (If active in database and within time window)
                if (activeSale != null &&
                    activeSale.items.isNotEmpty &&
                    _isFlashSaleTimeActive &&
                    _query.isEmpty)
                  SliverToBoxAdapter(
                    child: ScrollReveal(
                      offsetY: 18,
                      child: _buildFlashSaleSection(activeSale),
                    ),
                  ),

                // 5. Combo Carousel Banner (Real from DB)
                if (_query.isEmpty && widget.combos.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ScrollReveal(
                      delay: const Duration(milliseconds: 60),
                      offsetY: 18,
                      child: HomeComboCarousel(
                        combos: widget.combos,
                        onAddToCart: (combo) {
                          final addCombo = widget.onAddComboToCart;
                          if (addCombo != null) {
                            addCombo(combo);
                          } else {
                            widget.onAddToCart(combo.name);
                          }
                        },
                        onTapFood: _openFoodDetail,
                      ),
                    ),
                  ),

                // 5. Store Commitments
                if (_query.isEmpty && !widget.loading)
                  SliverToBoxAdapter(
                    child: ScrollReveal(
                      offsetY: 16,
                      child: _buildCommitments(),
                    ),
                  ),

                // 6. Best Sellers Section (🔥 Bán chạy - sorted from live DB)
                if (_topBestSellers.isNotEmpty && _query.isEmpty)
                  SliverToBoxAdapter(
                    child: ScrollReveal(
                      offsetY: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeading(
                            kicker: '🔥 BÁN CHẠY',
                            title: 'Món ăn bán chạy nhất',
                            action: 'Xem thêm',
                            onAction: () {},
                          ),
                          _buildBestSellersStrip(_topBestSellers),
                        ],
                      ),
                    ),
                  ),

                // Active Category Filter Bar (If filtered by Category from Left Drawer)
                if (_selectedCategory != 'Tất cả' && _query.isEmpty)
                  SliverToBoxAdapter(
                    child: ScrollReveal(
                      offsetY: 14,
                      child: _buildActiveCategoryFilterBanner(filtered.length),
                    ),
                  ),

                // 7. Food Catalog
                if (widget.loading)
                  const SliverToBoxAdapter(child: HomeScreenSkeleton())
                else if (widget.loadError != null)
                  SliverToBoxAdapter(child: _buildLoadError())
                else if (filtered.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState())
                else if (showGroupedCatalog)
                  SliverToBoxAdapter(child: _buildCategoryFoodSections())
                else ...[
                  SliverToBoxAdapter(
                    child: _buildSectionHeading(
                      kicker: 'THỰC ĐƠN',
                      title: _selectedCategory == 'Tất cả'
                          ? 'Kết quả tìm kiếm'
                          : _selectedCategory,
                      action: _selectedCategory != 'Tất cả'
                          ? '✕ Bỏ lọc'
                          : '${filtered.length} món',
                      onAction: () {
                        if (_selectedCategory != 'Tất cả') {
                          setState(() => _selectedCategory = 'Tất cả');
                        }
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildFoodCard(filtered[index]),
                        childCount: filtered.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.65,
                          ),
                    ),
                  ),
                ],

                // 8. Customer Reviews Section (Real from DB or fallback)
                if (_query.isEmpty && !widget.loading)
                  SliverToBoxAdapter(
                    child: ScrollReveal(
                      offsetY: 20,
                      child: _buildReviewsSection(),
                    ),
                  ),

                // 9. Store Footer
                if (_query.isEmpty && !widget.loading)
                  SliverToBoxAdapter(
                    child: ScrollReveal(
                      offsetY: 20,
                      child: _buildFooterSection(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HEADER ---
  Widget _buildHeader() {
    final unreadCount = widget.announcements
        .where((item) => !item.isRead)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
      child: Row(
        children: [
          // 1. Mobile Menu Button (Hamburger toggle on the left - identical to Web Mobile)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7F1),
                  border: Border.all(color: const Color(0xFFF4E5DC)),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: AppColors.ink,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 2. Brand Mark
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6E40), AppColors.orange],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text(
              '79',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bếp 1979',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'MÓN NGON MỖI NGÀY',
                  style: TextStyle(
                    color: AppColors.orange,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showVoucherSummary,
            tooltip: 'Voucher khuyến mãi',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.confirmation_num_outlined,
                  color: AppColors.ink,
                ),
                if (widget.availableVoucherCount > 0)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Badge(
                      label: Text('${widget.availableVoucherCount}'),
                      backgroundColor: AppColors.orange,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showAnnouncements,
            tooltip: 'Thông báo',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                if (unreadCount > 0)
                  RotationTransition(
                    turns: _bellRotation,
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.orangeDark,
                    ),
                  )
                else
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.ink,
                  ),
                if (unreadCount > 0)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Badge(
                      label: Text('$unreadCount'),
                      backgroundColor: const Color(0xFFE53935),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SEARCH BAR & SUGGESTIONS ---
  Widget _buildSearch() {
    final searchSuggestions = [
      {'label': '🍚 Cơm', 'query': 'Cơm'},
      {'label': '🍜 Phở', 'query': 'Phở'},
      {'label': '🥢 Bún', 'query': 'Bún'},
      {'label': '🍝 Mì', 'query': 'Mì'},
      {'label': '🍵 Trà', 'query': 'Trà'},
      {'label': '☕ Cà phê', 'query': 'Cà phê'},
      {'label': '🔥 Bán chạy', 'query': 'Bán chạy'},
      {'label': '⚡ Flash Sale', 'query': 'Flash Sale'},
    ];

    // Gợi ý món khớp khi đang nhập
    final liveMatches = _query.isNotEmpty
        ? widget.foods
              .where(
                (f) =>
                    f.name.toLowerCase().contains(_query.toLowerCase()) ||
                    f.category.toLowerCase().contains(_query.toLowerCase()),
              )
              .take(4)
              .toList()
        : <FoodItem>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Khung tìm kiếm chính
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _query.isNotEmpty ? AppColors.orange : AppColors.line,
                width: _query.isNotEmpty ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Bạn muốn ăn gì hôm nay?',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13.5,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.orange,
                  size: 22,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.orange,
                          size: 20,
                        ),
                        tooltip: 'Mở danh mục món (Bên trái)',
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                      ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // 2. Gợi ý từ khóa nhanh (khi chưa gõ)
          if (_query.isEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: searchSuggestions.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        final q = item['query']!;
                        _searchController.text = q;
                        setState(() => _query = q);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          item['label']!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // 3. Dropdown gợi ý trực tiếp ngay dưới ô tìm kiếm (khi đang gõ)
          if (_query.isNotEmpty && liveMatches.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCCBC)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GỢI Ý MÓN ĂN',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${liveMatches.length} gợi ý',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  ...liveMatches.map((food) {
                    final sale = _getFlashSale(food.id);
                    final isExplicitSale = sale != null;
                    final effectivePrice = isExplicitSale
                        ? sale.salePrice
                        : food.price;
                    final originalPrice = isExplicitSale
                        ? (sale.originalPrice > 0
                              ? sale.originalPrice
                              : food.price)
                        : food.oldPrice;
                    final hasDiscount =
                        originalPrice != null && originalPrice > effectivePrice;
                    final showNeon =
                        _isFlashSaleTimeActive &&
                        (isExplicitSale || hasDiscount);

                    return InkWell(
                      onTap: () => _openFoodDetail(food),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            showNeon
                                ? NeonSpinBorder(
                                    borderRadius: 6,
                                    borderWidth: 1.8,
                                    glow: true,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: SizedBox(
                                        width: 38,
                                        height: 38,
                                        child: AppImage(
                                          source: food.imageUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 38,
                                      height: 38,
                                      child: AppImage(
                                        source: food.imageUrl,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          food.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                      if (showNeon) ...[
                                        const SizedBox(width: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFFF007F),
                                                Color(0xFFFF5500),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: const Text(
                                            '⚡ SALE',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    food.category,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasDiscount)
                                  Text(
                                    '${_formatPrice(originalPrice)}đ',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: AppColors.muted,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  '${_formatPrice(effectivePrice)}đ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: showNeon
                                        ? const Color(0xFFE53935)
                                        : AppColors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- REAL FLASH SALE SECTION (SYNCHRONIZED WITH BACKEND) ---
  Widget _buildFlashSaleSection(FlashSaleCampaign campaign) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3E0), Color(0xFFFFEBE3)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCCBC)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5722).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3D00), Color(0xFFFF6E40)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3D00).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.9,
                        end: 1.25,
                      ).animate(_flameAnimController),
                      child: const Text('🔥', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'FLASH SALE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  campaign.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              // Countdown timer with red glowing numbers & blinking separators (Only this part rebuilds every 1s!)
              ValueListenableBuilder<Duration>(
                valueListenable: _remainingTimeNotifier,
                builder: (context, remainingTime, _) {
                  final hours = remainingTime.inHours.toString().padLeft(
                    2,
                    '0',
                  );
                  final minutes = (remainingTime.inMinutes % 60)
                      .toString()
                      .padLeft(2, '0');
                  final seconds = (remainingTime.inSeconds % 60)
                      .toString()
                      .padLeft(2, '0');
                  final isBlink = remainingTime.inSeconds % 2 == 0;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTimerBox(hours),
                      AnimatedOpacity(
                        opacity: isBlink ? 1.0 : 0.25,
                        duration: const Duration(milliseconds: 200),
                        child: const Text(
                          ' : ',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.orangeDark,
                          ),
                        ),
                      ),
                      _buildTimerBox(minutes),
                      AnimatedOpacity(
                        opacity: isBlink ? 1.0 : 0.25,
                        duration: const Duration(milliseconds: 200),
                        child: const Text(
                          ' : ',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.orangeDark,
                          ),
                        ),
                      ),
                      _buildTimerBox(seconds),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 188,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: campaign.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final item = campaign.items[idx];
                final food =
                    widget.foods
                        .where((f) => f.id == item.foodId)
                        .firstOrNull ??
                    FoodItem(
                      id: item.foodId,
                      name: item.name,
                      category: item.categoryName,
                      price: item.salePrice,
                      oldPrice: item.originalPrice,
                      imageUrl: item.image,
                      rating: 5.0,
                      sold: item.soldCount,
                    );

                final int sold = item.soldCount > 0
                    ? item.soldCount
                    : (8 + idx * 4);
                final double progress = (sold / (sold + 5)).clamp(0.35, 0.94);
                final hasDiscount = item.originalPrice > item.salePrice;
                final discountPercent = hasDiscount
                    ? (((item.originalPrice - item.salePrice) /
                                  item.originalPrice) *
                              100)
                          .round()
                    : 0;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openFoodDetail(food),
                    borderRadius: BorderRadius.circular(12),
                    child: NeonSpinBorder(
                      borderRadius: 12,
                      borderWidth: 2.2,
                      glow: true,
                      child: Container(
                        width: 130,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF007F)
                                  .withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: AspectRatio(
                                    aspectRatio: 1.25,
                                    child: AppImage(
                                      source: item.image,
                                      fit: BoxFit.cover,
                                      cacheWidth: 320,
                                      errorBuilder: (_, _, _) =>
                                          const ColoredBox(
                                            color: AppColors.soft,
                                            child: Icon(
                                              Icons.restaurant,
                                              color: AppColors.orange,
                                              size: 24,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                                if (hasDiscount)
                                  Positioned(
                                    top: 3,
                                    left: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFD50000),
                                            Color(0xFFFF3D00),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '-$discountPercent%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF007F),
                                          Color(0xFFFF5500),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text(
                                      'SALE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            if (hasDiscount)
                              Text(
                                '${_formatPrice(item.originalPrice)}đ',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: AppColors.muted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_formatPrice(item.salePrice)}đ',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFE53935),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => widget.onAddToCart(item.name),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.all(3.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.orange,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Hot Flash Sale Progress Bar
                            Container(
                              height: 13,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE0B2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  FractionallySizedBox(
                                    widthFactor: progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFF3D00),
                                            Color(0xFFFF9100),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      '🔥 ĐÃ BÁN ${(progress * 100).round()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBox(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // --- STORE COMMITMENTS ---
  Widget _buildCommitments() {
    const perks = [
      {
        'icon': Icons.speed_rounded,
        'title': 'Giao 30 phút',
        'desc': 'Nóng hổi đến tay',
      },
      {
        'icon': Icons.verified_rounded,
        'title': '100% Tươi sạch',
        'desc': 'Nguyên liệu sạch',
      },
      {
        'icon': Icons.discount_rounded,
        'title': 'Nhiều voucher',
        'desc': 'Giảm đến 50%',
      },
      {
        'icon': Icons.headset_mic_rounded,
        'title': 'Hỗ trợ 24/7',
        'desc': 'Tận tâm chu đáo',
      },
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: perks.map((item) {
          return Expanded(
            child: Column(
              children: [
                Icon(
                  item['icon'] as IconData,
                  color: AppColors.orange,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  item['title'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  item['desc'] as String,
                  style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- BEST SELLERS STRIP (SORTED FROM LIVE DATABASE) ---
  Widget _buildBestSellersStrip(List<FoodItem> items) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, idx) {
          final food = items[idx];
          final sale = _getFlashSale(food.id);
          final isExplicitSale = sale != null;
          final effectivePrice = isExplicitSale ? sale.salePrice : food.price;
          final originalPrice = isExplicitSale
              ? (sale.originalPrice > 0 ? sale.originalPrice : food.price)
              : food.oldPrice;
          final hasDiscount =
              originalPrice != null && originalPrice > effectivePrice;
          final showNeonSpin =
              _isFlashSaleTimeActive && (isExplicitSale || hasDiscount);

          final cardContainer = Container(
            width: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: showNeonSpin ? Colors.transparent : AppColors.line,
              ),
              boxShadow: [
                BoxShadow(
                  color: showNeonSpin
                      ? const Color(0xFFFF007F).withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: showNeonSpin ? 10 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: AspectRatio(
                        aspectRatio: 1.3,
                        child: AppImage(
                          source: food.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: AppColors.soft,
                            child: Icon(
                              Icons.restaurant,
                              color: AppColors.orange,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: idx < 3
                              ? const Color(0xFFD9480F)
                              : AppColors.ink,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'TOP ${idx + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    if (showNeonSpin)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF007F), Color(0xFFFF5500)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '⚡ SALE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${food.sold} lượt mua',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.muted,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasDiscount)
                                  Text(
                                    '${_formatPrice(originalPrice)}đ',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  '${_formatPrice(effectivePrice)}đ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: showNeonSpin
                                        ? const Color(0xFFE53935)
                                        : AppColors.orangeDark,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => widget.onAddToCart(food.name),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: showNeonSpin
                                      ? const Color(0xFFFF5500)
                                      : AppColors.orange,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 14,
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
          );

          final cardContent = showNeonSpin
              ? NeonSpinBorder(
                  borderRadius: 12,
                  borderWidth: 2.2,
                  glow: true,
                  child: cardContainer,
                )
              : cardContainer;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openFoodDetail(food),
              borderRadius: BorderRadius.circular(12),
              child: cardContent,
            ),
          );
        },
      ),
    );
  }

  // --- SECTION HEADING COMPONENT ---
  Widget _buildSectionHeading({
    required String kicker,
    required String title,
    required String action,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker.contains('BÁN CHẠY'))
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF3D00),
                          Color(0xFFFF6E40),
                          Color(0xFFFF9100),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3D00)
                              .withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RotationTransition(
                          turns: Tween<double>(
                            begin: -0.04,
                            end: 0.04,
                          ).animate(_flameAnimController),
                          child: const Text(
                            '🔥',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'BÁN CHẠY NHẤT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    kicker,
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                action,
                style: const TextStyle(
                  color: AppColors.orange,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- ACTIVE CATEGORY FILTER BANNER ---
  Widget _buildActiveCategoryFilterBanner(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD8BF)),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCategoryIcon(_selectedCategory),
              color: AppColors.orange,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DANH MỤC ĐANG XEM',
                  style: TextStyle(
                    color: AppColors.orangeDark,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '$_selectedCategory ($count món)',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => _selectedCategory = 'Tất cả'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCCBC)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.orangeDark,
                  ),
                  SizedBox(width: 3),
                  Text(
                    'Bỏ lọc',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.orangeDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- LEFT DRAWER (MATCHING MOBILE WEB SCREENSHOT media_1789526465559.png) ---
  Widget _buildCategoryDrawer() {
    final drawerWidth = (MediaQuery.of(context).size.width * 0.84).clamp(
      280.0,
      340.0,
    );

    return Drawer(
      width: drawerWidth,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(18)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Bar with Hamburger Close Button (☰)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF1E3D8)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_rounded,
                        color: Color(0xFF2C2724),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 2. Auth Header Buttons (or User Profile Card if logged in)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: widget.session == null
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onSelectTab?.call(3);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5722),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              'Đăng nhập',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onSelectTab?.call(3);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF3EB),
                              foregroundColor: const Color(0xFFFF5722),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              'Đăng ký',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1E3D8)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFFF5722),
                            backgroundImage:
                                widget.session!.user.avatar != null &&
                                    widget.session!.user.avatar!.isNotEmpty
                                ? NetworkImage(widget.session!.user.avatar!)
                                : null,
                            child:
                                widget.session!.user.avatar == null ||
                                    widget.session!.user.avatar!.isEmpty
                                ? Text(
                                    widget.session!.user.fullname.isNotEmpty
                                        ? widget.session!.user.fullname[0]
                                              .toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.session!.user.fullname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2C2724),
                                  ),
                                ),
                                Text(
                                  widget.session!.user.email.isNotEmpty
                                      ? widget.session!.user.email
                                      : widget.session!.user.phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8C7E77),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onSelectTab?.call(3);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFF5722),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Hồ sơ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // 3. Navigation Card Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                children: [
                  // Trang chủ
                  _buildDrawerCardItem(
                    label: 'Trang chủ',
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectTab?.call(0);
                    },
                  ),

                  // Đồ ăn ▾
                  _buildDrawerAccordionItem(
                    rootTitle: 'Đồ ăn',
                    rootSlug: 'do-an',
                    defaultChildren: const [
                      'Cơm',
                      'Phở',
                      'Mì',
                      'Bún',
                      'Burger',
                      'Pizza',
                      'Gà rán',
                    ],
                  ),

                  // Nước uống ▾
                  _buildDrawerAccordionItem(
                    rootTitle: 'Nước uống',
                    rootSlug: 'nuoc-uong',
                    defaultChildren: const [
                      'Trà',
                      'Cà phê',
                      'Nước ép và sinh tố',
                      'Nước đóng chai',
                    ],
                  ),

                  // Bánh kẹo ▾
                  _buildDrawerAccordionItem(
                    rootTitle: 'Bánh kẹo',
                    rootSlug: 'banh-keo',
                    defaultChildren: const [
                      'Bánh ngọt',
                      'Bánh quy',
                      'Kẹo sô cô la',
                    ],
                  ),

                  // Giỏ hàng
                  _buildDrawerCardItem(
                    label: 'Giỏ hàng',
                    badgeCount: widget.cartCount,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectTab?.call(2);
                    },
                  ),

                  // Lịch sử đơn
                  _buildDrawerCardItem(
                    label: 'Lịch sử đơn',
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectTab?.call(1);
                    },
                  ),

                  // Phản hồi
                  _buildDrawerCardItem(
                    label: 'Phản hồi',
                    onTap: () {
                      Navigator.of(context).pop();
                      _showFeedbackDialog();
                    },
                  ),

                  // Liên hệ
                  _buildDrawerCardItem(
                    label: 'Liên hệ',
                    onTap: () {
                      Navigator.of(context).pop();
                      _showContactDialog();
                    },
                  ),

                  // Voucher
                  _buildDrawerCardItem(
                    label: 'Voucher',
                    badgeCount: widget.availableVoucherCount,
                    onTap: () {
                      Navigator.of(context).pop();
                      _showVoucherSummary();
                    },
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DRAWER CARD ITEM WIDGET ---
  Widget _buildDrawerCardItem({
    required String label,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1E3D8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.015),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C2724),
                  ),
                ),
                const Spacer(),
                if (badgeCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5722),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- DRAWER EXPANDABLE ACCORDION ITEM WIDGET ---
  Widget _buildDrawerAccordionItem({
    required String rootTitle,
    required String rootSlug,
    required List<String> defaultChildren,
  }) {
    final isExpanded = _expandedDrawerCategories.contains(rootTitle);

    final rootCat = widget.categories
        .where(
          (c) =>
              !c.isChild &&
              (_normalize(c.name) == _normalize(rootTitle) ||
                  c.slug == rootSlug),
        )
        .firstOrNull;

    List<String> childNames = [];
    if (rootCat != null) {
      childNames = widget.categories
          .where((c) => c.parentId == rootCat.id)
          .map((c) => c.name)
          .toList();
    }
    if (childNames.isEmpty) {
      childNames = defaultChildren;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedDrawerCategories.remove(rootTitle);
                  } else {
                    _expandedDrawerCategories.add(rootTitle);
                  }
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1E3D8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.015),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      rootTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C2724),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isExpanded
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      color: const Color(0xFF2C2724),
                      size: 26,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 0, 4),
              padding: const EdgeInsets.only(left: 12),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFFF2D6C9), width: 1.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDrawerChildCard(
                    title: 'Tất cả $rootTitle',
                    onTap: () {
                      Navigator.of(context).pop();
                      _openCategoryScreen(rootTitle);
                    },
                  ),
                  for (final child in childNames)
                    _buildDrawerChildCard(
                      title: child,
                      onTap: () {
                        Navigator.of(context).pop();
                        _openCategoryScreen(child);
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerChildCard({
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1E3D8)),
            ),
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon(title),
                  size: 18,
                  color: const Color(0xFFFF5722),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3E332E),
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFFC7B8AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- DIALOGS FOR FEEDBACK & CONTACT ---
  void _showFeedbackDialog() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.rate_review_rounded,
                    color: AppColors.orange,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Gửi phản hồi cho Bếp 1979',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Ý kiến đóng góp của quý khách giúp chúng tôi ngày càng hoàn thiện chất lượng món ăn và dịch vụ.',
                style: TextStyle(fontSize: 13.5, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Nhập nội dung phản hồi hoặc góp ý...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFFF8F4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFF1E3D8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFF1E3D8)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showNotice('Cảm ơn bạn đã gửi phản hồi cho Bếp 1979!');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5722),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Gửi phản hồi',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactDialog() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.headset_mic_rounded,
                    color: AppColors.orange,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Thông tin liên hệ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildContactRow(
                Icons.phone_in_talk_rounded,
                'Hotline đặt món: 0387 700 547',
              ),
              _buildContactRow(
                Icons.access_time_filled_rounded,
                'Giờ mở cửa: 08:00 - 22:00 hàng ngày',
              ),
              _buildContactRow(
                Icons.location_on_rounded,
                'Địa chỉ: 123 Đường Ẩm Thực, Quận 1, TP. HCM',
              ),
              _buildContactRow(
                Icons.chat_bubble_rounded,
                'Zalo hỗ trợ: Bếp 1979 Official',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFFF5722)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF332924),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CUSTOMER REVIEWS SECTION (SYNCHRONIZED WITH BACKEND) ---
  Widget _buildReviewsSection() {
    final hasRealReviews = widget.reviews.isNotEmpty;
    final totalReviews = widget.reviews.length;
    final double avgRating = totalReviews > 0
        ? (widget.reviews.map((r) => r.rating).reduce((a, b) => a + b) /
              totalReviews)
        : 0;

    final filteredReviews = hasRealReviews
        ? (_selectedReviewRating == 0
              ? widget.reviews
              : widget.reviews
                    .where((r) => r.rating == _selectedReviewRating)
                    .toList())
        : const <FoodReviewItem>[];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4E2D19).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title & rating badge
          Row(
            children: [
              const Icon(
                Icons.rate_review_outlined,
                color: AppColors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Khách hàng nói gì về món ăn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFFCCBC)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.amber,
                      size: 15,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${avgRating.toStringAsFixed(1)} / 5',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.orangeDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Real Summary Badges (Like Web homeReviewSummary)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF0E5DC)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          color: AppColors.orange,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasRealReviews
                                  ? '$totalReviews+ đánh giá xác thực'
                                  : '100% Khách hàng thật',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const Text(
                              'Đã thưởng thức tại Bếp',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.line),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delivery_dining,
                          color: AppColors.green,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Giao hàng chuẩn vị',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              'Nóng hổi tận tay',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Star Filter Chips (Tất cả, 5 sao, 4 sao, 3 sao)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStarFilterChip(
                  label: 'Tất cả (${hasRealReviews ? totalReviews : 3})',
                  value: 0,
                ),
                const SizedBox(width: 6),
                _buildStarFilterChip(label: '5 sao ★', value: 5),
                const SizedBox(width: 6),
                _buildStarFilterChip(label: '4 sao ★', value: 4),
                const SizedBox(width: 6),
                _buildStarFilterChip(label: '3 sao ★', value: 3),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Review Items List
          if (hasRealReviews) ...[
            if (filteredReviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    'Không có bình luận nào cho mức $_selectedReviewRating sao.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: filteredReviews.take(4).map((r) {
                  return _buildReviewTile(
                    name: r.customerName,
                    food: r.foodName,
                    rating: r.rating,
                    comment: r.comment,
                    avatar: r.avatar,
                    createdAt: r.createdAt,
                    adminReply: r.adminReply,
                    isRealData: true,
                  );
                }).toList(),
              ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Chưa có đánh giá nào được hiển thị.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStarFilterChip({required String label, required int value}) {
    final active = _selectedReviewRating == value;
    return InkWell(
      onTap: () => setState(() => _selectedReviewRating = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.orange : const Color(0xFFF7F4F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.orange : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.ink,
            fontSize: 11,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewTile({
    required String name,
    required String food,
    required int rating,
    required String comment,
    String? avatar,
    String? createdAt,
    String? adminReply,
    bool isRealData = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF2E6DC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (avatar != null && avatar.isNotEmpty)
                  CircleAvatar(
                    radius: 15,
                    backgroundImage: NetworkImage(avatar),
                    backgroundColor: AppColors.soft,
                  )
                else
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'K',
                      style: const TextStyle(
                        color: AppColors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              '✓ Đã mua',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            food,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (createdAt != null && createdAt.isNotEmpty) ...[
                            Text(
                              ' • $createdAt',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(
                    rating.clamp(1, 5),
                    (_) => const Icon(
                      Icons.star_rounded,
                      color: AppColors.amber,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '“$comment”',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.ink,
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
            // Admin Reply Box (If available from database)
            if (adminReply != null && adminReply.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFFFCCBC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('👨‍🍳 ', style: TextStyle(fontSize: 11)),
                        Text(
                          'Bếp 1979 phản hồi:',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.orangeDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      adminReply,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.ink,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- STORE FOOTER SECTION (SYNCHRONIZED WITH WEB SHARED FOOTER) ---
  Widget _buildFooterSection() {
    const textColor = Color(0xFFFFF7ED);
    final mutedText = textColor.withValues(alpha: 0.82);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF3A291F),
        border: Border(top: BorderSide(color: Color(0x1FFFFFFF), width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Footer Brand
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE65100), Color(0xFFFF7043)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  '79',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bếp 1979',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Món ngon mỗi ngày',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.68),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Nền tảng giao đồ ăn hiện đại, kết nối khách hàng với thực đơn tươi ngon, thanh toán linh hoạt và theo dõi đơn hàng minh bạch.',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.88),
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),

          // Contact List
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _showNotice('Hotline Bếp 1979: 0387 700 547'),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.phone_in_talk_rounded,
                        color: AppColors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hotline: ',
                        style: TextStyle(color: mutedText, fontSize: 13),
                      ),
                      const Text(
                        '0387 700 547',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _showNotice('Email: tdchinh04@gmail.com'),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        color: AppColors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Email: ',
                        style: TextStyle(color: mutedText, fontSize: 13),
                      ),
                      const Text(
                        'tdchinh04@gmail.com',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: AppColors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Giờ phục vụ: 08:00 - 22:00 hằng ngày',
                      style: TextStyle(color: mutedText, fontSize: 12.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Social Icons Row
          Row(
            children: [
              _buildFooterSocialButton(
                icon: Icons.language_rounded,
                tooltip: 'Website Bếp 1979',
                onTap: () => _showNotice('Website Bếp 1979'),
              ),
              const SizedBox(width: 12),
              _buildFooterSocialButton(
                icon: Icons.mail_outline_rounded,
                tooltip: 'Email Bếp 1979',
                onTap: () => _showNotice('Email: tdchinh04@gmail.com'),
              ),
              const SizedBox(width: 12),
              _buildFooterSocialButton(
                icon: Icons.call_rounded,
                tooltip: 'Hotline Bếp 1979',
                onTap: () => _showNotice('Hotline: 0387 700 547'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // 2. Footer Links Grid (2 Columns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: KHÁM PHÁ & KHÁCH HÀNG
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFooterLinkGroupTitle('KHÁM PHÁ'),
                    _buildFooterLinkItem(
                      'Trang chủ',
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _selectedCategory = 'Tất cả';
                        });
                      },
                    ),
                    _buildFooterLinkItem(
                      'Thực đơn',
                      onTap: () => _openCategoryScreen('Tất cả thực đơn'),
                    ),
                    _buildFooterLinkItem(
                      'Đồ ăn',
                      onTap: () => _openCategoryScreen('Đồ ăn'),
                    ),
                    _buildFooterLinkItem(
                      'Nước uống',
                      onTap: () => _openCategoryScreen('Nước uống'),
                    ),
                    const SizedBox(height: 20),
                    _buildFooterLinkGroupTitle('KHÁCH HÀNG'),
                    _buildFooterLinkItem(
                      'Giỏ hàng (${widget.cartCount})',
                      onTap: () {
                        _showNotice(
                          'Giỏ hàng hiện có ${widget.cartCount} món ăn.',
                        );
                      },
                    ),
                    _buildFooterLinkItem(
                      'Lịch sử đơn',
                      onTap: () {
                        _showNotice('Vui lòng chuyển sang tab Đơn hàng.');
                      },
                    ),
                    _buildFooterLinkItem(
                      'Thông báo',
                      onTap: _showAnnouncements,
                    ),
                    _buildFooterLinkItem(
                      'Voucher (${widget.availableVoucherCount})',
                      onTap: _showVoucherSummary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Column 2: HỖ TRỢ & CAM KẾT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFooterLinkGroupTitle('HỖ TRỢ'),
                    _buildFooterLinkItem(
                      'Trung tâm hỗ trợ',
                      onTap: () => _showNotice('Trung tâm CSKH: 0387 700 547'),
                    ),
                    _buildFooterLinkItem(
                      'Gửi phản hồi',
                      onTap: () => _showNotice(
                        'Cảm ơn bạn đã đóng góp ý kiến cho Bếp 1979!',
                      ),
                    ),
                    _buildFooterLinkItem(
                      'Hợp tác cửa hàng',
                      onTap: () =>
                          _showNotice('Liên hệ hợp tác: tdchinh04@gmail.com'),
                    ),
                    _buildFooterLinkItem(
                      'Liên hệ Bếp 1979',
                      onTap: () =>
                          _showNotice('Bếp 1979 hân hạnh phục vụ quý khách!'),
                    ),
                    const SizedBox(height: 20),
                    _buildFooterLinkGroupTitle('CAM KẾT'),
                    _buildFooterCommitmentItem('Món ăn cập nhật từ hệ thống'),
                    _buildFooterCommitmentItem('Kiểm tra tồn kho khi đặt hàng'),
                    _buildFooterCommitmentItem('Theo dõi trạng thái đơn'),
                    _buildFooterCommitmentItem('Hỗ trợ COD, QR và VNPay'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // 3. Store Map Card
          Container(
            height: 155,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Simulated Map Graphic Background with road grid and location pin
                Container(
                  color: const Color(0xFF281D17),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _FooterMapPainter(),
                  ),
                ),
                // Center Map Marker Pin
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5722),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF5722)
                                  .withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Bếp 1979 • 10.1005, 105.6865',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Floating map badge (header)
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A291F).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              color: AppColors.orange,
                              size: 15,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Bếp 1979 Store',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _showNotice(
                            'Tọa độ Bếp 1979: 10.100528, 105.686583',
                          ),
                          child: const Text(
                            'Mở bản đồ lớn ↗',
                            style: TextStyle(
                              color: Color(0xFFFFB08A),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 4. Footer Bottom
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '© 2026 Bếp 1979. All rights reserved.',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Designed by Tran Duc Chinh IT',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSocialButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: const Color(0xFFFFF7ED), size: 20),
        ),
      ),
    );
  }

  Widget _buildFooterLinkGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFFF7ED),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFooterLinkItem(String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: const Color(0xFFFFF7ED).withValues(alpha: 0.82),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterCommitmentItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: AppColors.orange,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: const Color(0xFFFFF7ED).withValues(alpha: 0.78),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.muted, size: 40),
          const SizedBox(height: 10),
          Text(
            widget.loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, color: AppColors.muted, size: 42),
            SizedBox(height: 10),
            Text(
              'Không tìm thấy món ăn phù hợp.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Hãy thử tìm với từ khóa hoặc danh mục khác nhé!',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(int value) {
    final digits = value.toString();
    final chunks = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      chunks.insert(0, digits.substring((end - 3).clamp(0, end), end));
    }
    return chunks.join('.');
  }
}

class _FooterMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFF45342B)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final mainRoadPaint = Paint()
      ..color = const Color(0xFF5A4438)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    final riverPaint = Paint()
      ..color = const Color(0xFF1E3A4A).withValues(alpha: 0.7)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    // Curved river
    final riverPath = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.95,
        size.width,
        size.height * 0.45,
      );
    canvas.drawPath(riverPath, riverPaint);

    // Grid roads
    canvas.drawLine(
      Offset(0, size.height * 0.35),
      Offset(size.width, size.height * 0.35),
      mainRoadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.65),
      Offset(size.width, size.height * 0.65),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.28, 0),
      Offset(size.width * 0.28, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.68, 0),
      Offset(size.width * 0.68, size.height),
      mainRoadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// HOME COMBO CAROUSEL (Dedicated Section for Combos)
// ============================================================================

class HomeComboCarousel extends StatefulWidget {
  const HomeComboCarousel({
    super.key,
    required this.combos,
    required this.onAddToCart,
    this.onTapFood,
  });

  final List<ComboItem> combos;
  final ValueChanged<ComboItem> onAddToCart;
  final void Function(FoodItem)? onTapFood;

  @override
  State<HomeComboCarousel> createState() => _HomeComboCarouselState();
}

class _HomeComboCarouselState extends State<HomeComboCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.93);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (widget.combos.length <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 4000), (
      timer,
    ) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % widget.combos.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _pauseAutoScroll() {
    _autoScrollTimer?.cancel();
  }

  String _formatPrice(int value) {
    final digits = value.toString();
    final chunks = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      chunks.insert(0, digits.substring((end - 3).clamp(0, end), end));
    }
    return '${chunks.join('.')}đ';
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.combos.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6D00), Color(0xFFFF9100)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🍱', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 4),
                        Text(
                          'COMBO TIẾT KIỆM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Ưu đãi đặc biệt hôm nay',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              if (widget.combos.length > 1)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    widget.combos.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: _currentPage == index ? 16 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppColors.orange
                            : const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 175,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _pauseAutoScroll();
              } else if (notification is ScrollEndNotification) {
                _startAutoScroll();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.combos.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final combo = widget.combos[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 4,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppImage(source: combo.image, fit: BoxFit.cover),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.black.withValues(alpha: 0.85),
                                ],
                                stops: const [0.35, 0.65, 1.0],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 12,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        combo.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      if (combo.description != null &&
                                          combo.description!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          combo.description!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.85,
                                            ),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatPrice(combo.price),
                                        style: const TextStyle(
                                          color: Color(0xFFFFD54F),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () => widget.onAddToCart(combo),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_shopping_cart, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Chọn mua',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
