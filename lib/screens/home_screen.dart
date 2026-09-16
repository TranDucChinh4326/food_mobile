import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/combo_item.dart';
import '../models/flash_sale.dart';
import '../models/food_item.dart';
import '../models/food_review_item.dart';
import '../models/home_content.dart';
import '../widgets/app_image.dart';
import '../widgets/food_card.dart';
import '../widgets/skeleton_loader.dart';
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
    required this.onToggleFavorite,
    this.onMarkAnnouncementsRead,
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
  final ValueChanged<int> onToggleFavorite;
  final Future<void> Function(List<int>)? onMarkAnnouncementsRead;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'Tất cả';
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final PageController _comboPageController = PageController();
  int _currentComboPage = 0;
  int _selectedReviewRating = 0; // 0 for All, or 5, 4, 3

  Timer? _timer;
  Timer? _comboTimer;
  Duration _remainingTime = Duration.zero;
  late final AnimationController _flameAnimController;

  @override
  void initState() {
    super.initState();
    _flameAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _initCountdown();
    _startComboAutoPlay();
  }

  void _startComboAutoPlay() {
    _comboTimer?.cancel();
    _comboTimer = Timer.periodic(const Duration(milliseconds: 4000), (timer) {
      if (!mounted || !_comboPageController.hasClients) return;
      final count = widget.combos.isNotEmpty ? widget.combos.length : 3;
      if (count <= 1) return;
      final next = (_currentComboPage + 1) % count;
      _comboPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flashSales != widget.flashSales) {
      _initCountdown();
    }
    if (oldWidget.combos != widget.combos) {
      _startComboAutoPlay();
    }
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
        _remainingTime = diff.isNegative ? Duration.zero : diff;
      } catch (_) {
        _remainingTime = const Duration(hours: 3, minutes: 45);
      }
    } else {
      _remainingTime = const Duration(hours: 3, minutes: 45);
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _comboTimer?.cancel();
    _flameAnimController.dispose();
    _searchController.dispose();
    _comboPageController.dispose();
    super.dispose();
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
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

  FoodCard _buildFoodCard(FoodItem food) {
    return FoodCard(
      food: food,
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
        return Column(
          children: [
            _buildSectionHeading(
              kicker: 'THỰC ĐƠN',
              title: name,
              action: 'Xem tất cả',
              onAction: () => setState(() => _selectedCategory = name),
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
        );
      }).toList(),
    );
  }

  Widget _buildAnnouncementTicker() {
    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2B1C16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: widget.announcements.length,
        separatorBuilder: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text('•', style: TextStyle(color: AppColors.orange)),
          ),
        ),
        itemBuilder: (context, index) {
          final item = widget.announcements[index];
          return InkWell(
            onTap: _showAnnouncements,
            child: Center(
              child: Row(
                children: [
                  if (!item.isRead) ...[
                    const Icon(
                      Icons.fiber_new,
                      color: AppColors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdvertisements() {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        scrollDirection: Axis.horizontal,
        itemCount: widget.advertisements.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final advertisement = widget.advertisements[index];
          return InkWell(
            onTap: () {
              final foodId = advertisement.linkedFoodId;
              final food = widget.foods
                  .where((item) => item.id == foodId)
                  .firstOrNull;
              if (food != null) _openFoodDetail(food);
            },
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 230,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(
                      source: advertisement.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.soft,
                        child: Icon(Icons.campaign, color: AppColors.orange),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xAA1D100B)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 8,
                      child: Text(
                        advertisement.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final filtered = widget.foods.where((food) {
      final matchesCategory =
          _selectedCategory == 'Tất cả' || food.category == _selectedCategory;
      return matchesCategory &&
          food.name.toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();

    // Top best sellers sorted by sold count
    final bestSellers = widget.foods.where((food) => food.sold > 0).toList()
      ..sort((a, b) => b.sold.compareTo(a.sold));
    final topBestSellers = bestSellers.take(5).toList();
    final showGroupedCatalog =
        _query.trim().isEmpty && _selectedCategory == 'Tất cả';

    final activeSale = widget.flashSales
        .where((s) => s.items.isNotEmpty)
        .firstOrNull;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          // 1. Header Top
          SliverToBoxAdapter(child: _buildHeader()),

          // 2. Search & Filter Bar
          SliverToBoxAdapter(child: _buildSearch()),

          if (_query.isEmpty && widget.announcements.isNotEmpty)
            SliverToBoxAdapter(child: _buildAnnouncementTicker()),

          if (_query.isEmpty && widget.advertisements.isNotEmpty)
            SliverToBoxAdapter(child: _buildAdvertisements()),

          // 3. Real Flash Sale Section (If active in database)
          if (activeSale != null &&
              activeSale.items.isNotEmpty &&
              _query.isEmpty)
            SliverToBoxAdapter(child: _buildFlashSaleSection(activeSale)),

          // 4. Combo Carousel Banner (Real from DB)
          if (_query.isEmpty && widget.combos.isNotEmpty)
            SliverToBoxAdapter(child: _buildComboCarousel()),

          // 5. Store Commitments
          if (_query.isEmpty) SliverToBoxAdapter(child: _buildCommitments()),

          // 6. Categories Header & Bar
          SliverToBoxAdapter(
            child: _buildSectionHeading(
              kicker: 'THỰC ĐƠN',
              title: 'Danh mục',
              action: 'Xem tất cả',
              onAction: () => setState(() => _selectedCategory = 'Tất cả'),
            ),
          ),
          SliverToBoxAdapter(child: _buildCategories()),

          // 7. Best Sellers Section (🔥 Bán chạy - sorted from live DB)
          if (topBestSellers.isNotEmpty && _query.isEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeading(
                kicker: '🔥 BÁN CHẠY',
                title: 'Món ăn bán chạy nhất',
                action: 'Xem thêm',
                onAction: () {},
              ),
            ),
            SliverToBoxAdapter(child: _buildBestSellersStrip(topBestSellers)),
          ],

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
                action: '${filtered.length} món',
                onAction: () {},
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildFoodCard(filtered[index]),
                  childCount: filtered.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.65,
                ),
              ),
            ),
          ],

          // 10. Customer Reviews Section (Real from DB or fallback)
          if (_query.isEmpty) SliverToBoxAdapter(child: _buildReviewsSection()),

          // 11. Store Footer
          if (_query.isEmpty) SliverToBoxAdapter(child: _buildFooterSection()),
        ],
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
          Container(
            width: 46,
            height: 46,
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
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bếp 1979',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'MÓN NGON MỖI NGÀY',
                  style: TextStyle(
                    color: AppColors.orange,
                    fontSize: 10,
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
          Badge(
            label: Text('${widget.cartCount}'),
            isLabelVisible: widget.cartCount > 0,
            backgroundColor: AppColors.orange,
            child: IconButton(
              onPressed: () =>
                  _showNotice('Giỏ hàng hiện có ${widget.cartCount} món'),
              tooltip: 'Giỏ hàng',
              icon: const Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SEARCH BAR ---
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
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
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
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
                : const Icon(
                    Icons.tune_rounded,
                    color: AppColors.muted,
                    size: 20,
                  ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // --- REAL FLASH SALE SECTION (SYNCHRONIZED WITH BACKEND) ---
  Widget _buildFlashSaleSection(FlashSaleCampaign campaign) {
    final hours = _remainingTime.inHours.toString().padLeft(2, '0');
    final minutes = (_remainingTime.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remainingTime.inSeconds % 60).toString().padLeft(2, '0');

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
              // Countdown timer with red glowing numbers
              _buildTimerBox(hours),
              const Text(
                ' : ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.orangeDark,
                ),
              ),
              _buildTimerBox(minutes),
              const Text(
                ' : ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.orangeDark,
                ),
              ),
              _buildTimerBox(seconds),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 182,
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
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 126,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.line),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
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
                                  child: Image.network(
                                    item.image,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const ColoredBox(
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
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFD50000),
                                          Color(0xFFFF3D00),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
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

  // --- COMBO CAROUSEL BANNER (REAL COMBOS OR FEATURED FALLBACK) ---
  Widget _buildComboCarousel() {
    // If backend has combos, use them! Otherwise use featured combos
    final hasRealCombos = widget.combos.isNotEmpty;
    final bannerCount = hasRealCombos ? widget.combos.length : 3;

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _comboPageController,
            itemCount: bannerCount,
            onPageChanged: (idx) => setState(() => _currentComboPage = idx),
            itemBuilder: (context, index) {
              final String title = hasRealCombos
                  ? widget.combos[index].name
                  : (index == 0
                        ? 'Combo Cơm Trưa'
                        : (index == 1
                              ? 'Combo Bữa Cơm Nhà'
                              : 'Combo Lẩu Thái Hải Sản'));
              final String desc = hasRealCombos
                  ? (widget.combos[index].description ??
                        'Món ngon tròn vị, ưu đãi hấp dẫn')
                  : (index == 0
                        ? 'Cơm gà + Coca-Cola, đủ ngon và tiết kiệm'
                        : (index == 1
                              ? 'Thịt kho tàu, Canh chua & Rau xào tỏi ấm cúng'
                              : 'Hải sản tươi rói, nước lẩu chua cay đậm đà'));
              final String price = hasRealCombos
                  ? '${_formatPrice(widget.combos[index].price)}đ'
                  : (index == 0
                        ? '65.000đ'
                        : (index == 1 ? '155.000đ' : '249.000đ'));
              final String img =
                  hasRealCombos && widget.combos[index].image.isNotEmpty
                  ? widget.combos[index].image
                  : (index == 0
                        ? 'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1200&q=85'
                        : (index == 1
                              ? 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1200&q=85'
                              : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=85'));

              final comboFood = FoodItem(
                id: hasRealCombos ? widget.combos[index].id : (99990 + index),
                name: title,
                category: 'Combo',
                price: hasRealCombos
                    ? widget.combos[index].price
                    : (index == 0 ? 65000 : (index == 1 ? 155000 : 249000)),
                imageUrl: img,
                description: desc,
                rating: 5.0,
                sold: hasRealCombos ? widget.combos[index].maxAvailable : 100,
              );

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E170F),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4E2D19).withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  image: DecorationImage(
                    image: NetworkImage(img),
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    opacity: 0.42,
                    onError: (_, _) {},
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openFoodDetail(comboFood),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'COMBO ĐẶC SẮC',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFFFE5D8),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'GIÁ TRỌN GÓI',
                                    style: TextStyle(
                                      color: Color(0xFFFFC29B),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  Text(
                                    price,
                                    style: const TextStyle(
                                      color: Color(0xFFFFC13B),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              FilledButton.icon(
                                onPressed: () => widget.onAddToCart(title),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.orange,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.shopping_cart_checkout,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Đặt ngay',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
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
        const SizedBox(height: 10),
        // Dots indicator with active expansion & glow
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(bannerCount, (idx) {
            final active = idx == _currentComboPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 26 : 7,
              height: 7,
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(
                        colors: [Color(0xFFFFD166), AppColors.orange],
                      )
                    : null,
                color: active ? null : const Color(0xFFDCD6D0),
                borderRadius: BorderRadius.circular(4),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.orange.withValues(alpha: 0.45),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
      ],
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
      height: 196,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, idx) {
          final food = items[idx];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openFoodDetail(food),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
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
                            aspectRatio: 1.35,
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
                                Text(
                                  '${_formatPrice(food.price)}đ',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.orangeDark,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => widget.onAddToCart(food.name),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.orange,
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
              ),
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

  // --- CATEGORIES BAR ---
  Widget _buildCategories() {
    final categories = _categories;
    final icons = [
      Icons.restaurant_menu_rounded,
      Icons.rice_bowl_rounded,
      Icons.ramen_dining_rounded,
      Icons.soup_kitchen_rounded,
      Icons.local_fire_department_rounded,
      Icons.local_drink_rounded,
      Icons.cake_rounded,
    ];

    return SizedBox(
      height: 78,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == _selectedCategory;
          final icon = icons[index % icons.length];

          return InkWell(
            onTap: () => setState(() => _selectedCategory = category),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 82,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.orange : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.orange : AppColors.line,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.orange.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: selected ? Colors.white : AppColors.orange,
                    size: 24,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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

  // --- STORE FOOTER SECTION ---
  Widget _buildFooterSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),
      color: const Color(0xFF241812),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '79',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hệ Thống Bếp 1979',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'MÓN NGON MỖI NGÀY',
                    style: TextStyle(
                      color: Color(0xFFFFAB91),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Hotline đặt món: 1900 1979 • 08:00 - 22:00',
            style: TextStyle(
              color: Color(0xFFFFCCBC),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Địa chỉ: 79 Đường Ẩm Thực, Quận 1, TP. Hồ Chí Minh',
            style: TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          const Text(
            '© 2026 Bếp 1979. Nền tảng đặt món ăn online chính thức.',
            style: TextStyle(color: Colors.white38, fontSize: 10.5),
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

  List<String> get _categories {
    final foodCategoryNames = widget.foods
        .map((food) => food.category)
        .where((name) => name.trim().isNotEmpty)
        .toSet();
    final apiCategories = widget.categories
        .where((category) => category.isChild)
        .where((category) => foodCategoryNames.contains(category.name))
        .map((category) => category.name)
        .toList();
    final remaining = foodCategoryNames.where(
      (name) => !apiCategories.contains(name),
    );
    return ['Tất cả', ...apiCategories, ...remaining];
  }
}
