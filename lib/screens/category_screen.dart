import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/flash_sale.dart';
import '../models/food_item.dart';
import '../models/home_content.dart';
import '../widgets/food_card.dart';
import 'food_detail_screen.dart';

enum CategorySortOption {
  popular('Phổ biến nhất', Icons.auto_awesome),
  priceAsc('Giá: Thấp đến cao', Icons.arrow_upward_rounded),
  priceDesc('Giá: Cao đến thấp', Icons.arrow_downward_rounded),
  rating('Đánh giá cao nhất', Icons.star_rounded),
  sales('Bán chạy nhất', Icons.local_fire_department_rounded);

  const CategorySortOption(this.label, this.icon);
  final String label;
  final IconData icon;
}

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
    required this.categoryName,
    required this.allFoods,
    required this.categories,
    required this.flashSales,
    required this.favorites,
    required this.cartCount,
    required this.onAddToCart,
    required this.onToggleFavorite,
    this.initialSort = CategorySortOption.popular,
    this.initialOnlySale = false,
  });

  final String categoryName;
  final List<FoodItem> allFoods;
  final List<FoodCategory> categories;
  final List<FlashSaleCampaign> flashSales;
  final Set<int> favorites;
  final int cartCount;
  final ValueChanged<String> onAddToCart;
  final ValueChanged<int> onToggleFavorite;
  final CategorySortOption initialSort;
  final bool initialOnlySale;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late String _currentCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late CategorySortOption _selectedSort;
  late bool _onlySale;

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.categoryName;
    _selectedSort = widget.initialSort;
    _onlySale = widget.initialOnlySale;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- GET RELATED SUBCATEGORIES ---
  List<String> _getSubcategories() {
    // If "Tất cả" or "Tất cả thực đơn", show all available child categories
    final isAll =
        _isAllCategory(_currentCategory) || _isAllCategory(widget.categoryName);

    if (isAll) {
      final names = widget.allFoods
          .map((f) => f.category)
          .where((name) => name.trim().isNotEmpty)
          .toSet()
          .toList();
      return ['Tất cả', ...names];
    }

    // Check if current or parent is a root category (e.g. Đồ ăn, Nước uống)
    final normWidgetCat = _normalize(widget.categoryName);
    final root = widget.categories
        .where(
          (c) =>
              !c.isChild &&
              (_normalize(c.name) == normWidgetCat ||
                  c.slug == normWidgetCat.replaceAll(' ', '-')),
        )
        .firstOrNull;

    if (root != null) {
      final children = widget.categories
          .where((c) => c.parentId == root.id)
          .map((c) => c.name)
          .toList();
      return ['Tất cả ${root.name}', ...children];
    }

    // If viewing a specific subcategory (e.g. Mì, Cơm), find sibling subcategories
    final normCurrent = _normalize(_currentCategory);
    final currentCatObj = widget.categories
        .where(
          (c) =>
              _normalize(c.name) == normCurrent ||
              c.slug == normCurrent.replaceAll(' ', '-'),
        )
        .firstOrNull;

    if (currentCatObj != null && currentCatObj.isChild) {
      final siblings = widget.categories
          .where((c) => c.parentId == currentCatObj.parentId)
          .map((c) => c.name)
          .toList();
      if (siblings.isNotEmpty) {
        return ['Tất cả', ...siblings];
      }
    }

    // Fallback based on known food vs drink category
    if ([
      'mi',
      'com',
      'pho',
      'bun',
      'burger',
      'pizza',
      'ga ran',
    ].contains(normCurrent)) {
      final foodChildren = widget.categories
          .where((c) => c.isChild && c.parentId == 100)
          .map((c) => c.name)
          .toList();
      if (foodChildren.isNotEmpty) {
        return ['Tất cả', ...foodChildren];
      }
      return const ['Tất cả', 'Cơm', 'Phở', 'Mì', 'Bún', 'Burger', 'Pizza'];
    }

    if ([
      'tra',
      'ca phe',
      'nuoc dong chai',
      'nuoc ep va sinh to',
    ].contains(normCurrent)) {
      final drinkChildren = widget.categories
          .where((c) => c.isChild && c.parentId == 101)
          .map((c) => c.name)
          .toList();
      if (drinkChildren.isNotEmpty) {
        return ['Tất cả', ...drinkChildren];
      }
      return const [
        'Tất cả',
        'Trà',
        'Cà phê',
        'Nước ép và sinh tố',
        'Nước đóng chai',
      ];
    }

    return [];
  }

  bool _isAllCategory(String name) {
    final lower = name.toLowerCase();
    return lower == 'tất cả' ||
        lower.contains('tất cả thực đơn') ||
        lower.startsWith('tất cả');
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
    if (_isAllCategory(selectedCategory)) {
      if (_isAllCategory(widget.categoryName)) {
        return true;
      }
      final normWidgetCat = _normalize(widget.categoryName);
      final rootCat = widget.categories
          .where(
            (c) =>
                !c.isChild &&
                (_normalize(c.name) == normWidgetCat ||
                    c.slug == normWidgetCat.replaceAll(' ', '-')),
          )
          .firstOrNull;
      if (rootCat != null) {
        final childIds = widget.categories
            .where((c) => c.parentId == rootCat.id)
            .map((c) => c.id)
            .toSet();
        final childSlugs = widget.categories
            .where((c) => c.parentId == rootCat.id)
            .map((c) => c.slug.toLowerCase())
            .toSet();
        final childNames = widget.categories
            .where((c) => c.parentId == rootCat.id)
            .map((c) => _normalize(c.name))
            .toSet();

        final matchesRoot =
            food.parentCategoryId == rootCat.id ||
            (food.parentCategorySlug != null &&
                food.parentCategorySlug!.toLowerCase() ==
                    rootCat.slug.toLowerCase()) ||
            _normalize(food.parentCategoryName ?? '') ==
                _normalize(rootCat.name) ||
            food.categoryId == rootCat.id ||
            (food.categorySlug != null &&
                food.categorySlug!.toLowerCase() ==
                    rootCat.slug.toLowerCase()) ||
            _normalize(food.category) == _normalize(rootCat.name);

        final matchesChild =
            (food.categoryId != null && childIds.contains(food.categoryId)) ||
            (food.categorySlug != null &&
                childSlugs.contains(food.categorySlug!.toLowerCase())) ||
            childNames.contains(_normalize(food.categoryName ?? '')) ||
            childNames.contains(_normalize(food.category));

        return matchesRoot || matchesChild;
      }
      return true;
    }

    final normTarget = _normalize(selectedCategory);
    final targetSlug = normTarget.replaceAll(' ', '-');

    // SPECIAL RULE FOR NOODLES ("MÌ" / "MỲ")
    final isTargetNoodle =
        normTarget == 'mi' ||
        normTarget == 'my' ||
        normTarget == 'mon mi' ||
        targetSlug == 'mi';

    if (isTargetNoodle) {
      // 1. NEVER include Bánh mì under Mì!
      if (_isBanhMi(food)) return false;

      // 2. Exact match by category object
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

      // 3. Match by food category name / slug
      if (food.categorySlug?.toLowerCase() == 'mi') return true;
      if (_normalize(food.categoryName ?? '') == 'mi') return true;
      if (_normalize(food.category) == 'mi') return true;

      // 4. Match if food name contains "mì" / "mỳ" as a standalone word (excluding bánh mì)
      final noodleRegex = RegExp(
        r'(?<!banh\s)\b(mi|my)\b',
        caseSensitive: false,
      );
      return noodleRegex.hasMatch(_normalize(food.name)) ||
          noodleRegex.hasMatch(_normalize(food.categoryName ?? food.category));
    }

    // GENERAL CATEGORY MATCHING (e.g. Cơm, Phở, Bún, Trà, Cà phê...)
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

    // Word boundary or contains for multi-word categories
    if (normFoodCat.contains(normTarget)) {
      return true;
    }

    return false;
  }

  bool _foodMatchesSearch(FoodItem food, String query) {
    final q = query.trim();
    if (q.isEmpty) return true;

    final normQ = _normalize(q);
    final normName = _normalize(food.name);
    final normDesc = _normalize(food.description ?? '');
    final normCat = _normalize(food.categoryName ?? food.category);

    // If search is specifically for noodles: "mi", "mì", "mỳ", "mon mi", "món mì"
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

  // --- FILTER & SORT FOODS ---
  List<FoodItem> _getFilteredFoods() {
    return widget.allFoods.where((food) {
      // Category Match
      if (!_foodMatchesCategory(food, _currentCategory)) {
        return false;
      }

      // Search Query
      if (!_foodMatchesSearch(food, _searchQuery)) {
        return false;
      }

      // Only Sale filter
      if (_onlySale) {
        final hasDirectDiscount =
            food.oldPrice != null && food.oldPrice! > food.price;
        final isInFlashSale = _getFlashSale(food.id) != null;
        if (!hasDirectDiscount && !isInFlashSale) return false;
      }

      return true;
    }).toList()..sort((a, b) {
      int effectivePrice(FoodItem f) {
        final sale = _getFlashSale(f.id);
        if (sale != null && sale.salePrice > 0 && sale.salePrice < f.price) {
          return sale.salePrice;
        }
        return f.price;
      }

      switch (_selectedSort) {
        case CategorySortOption.priceAsc:
          return effectivePrice(a).compareTo(effectivePrice(b));
        case CategorySortOption.priceDesc:
          return effectivePrice(b).compareTo(effectivePrice(a));
        case CategorySortOption.rating:
          return b.rating.compareTo(a.rating);
        case CategorySortOption.sales:
          return b.sold.compareTo(a.sold);
        case CategorySortOption.popular:
          return b.sold.compareTo(a.sold);
      }
    });
  }

  FlashSaleItem? _getFlashSale(int foodId) {
    for (final campaign in widget.flashSales) {
      for (final item in campaign.items) {
        if (item.foodId == foodId) return item;
      }
    }
    return null;
  }

  bool get _isFlashSaleTimeActive {
    return widget.flashSales.any((s) => s.isCurrentlyActive);
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
    if (lower.contains('nướng')) return Icons.local_fire_department_rounded;
    if (lower.contains('kho')) return Icons.dinner_dining_rounded;
    if (lower.contains('canh')) return Icons.soup_kitchen_rounded;
    if (lower.contains('lẩu')) return Icons.set_meal_rounded;
    if (lower.contains('combo')) return Icons.fastfood_rounded;
    if (lower.contains('bánh') || lower.contains('tráng miệng')) {
      return Icons.cake_rounded;
    }
    return Icons.restaurant_menu_rounded;
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
          allFoods: widget.allFoods,
          flashSales: widget.flashSales,
        ),
      ),
    );
  }

  void _showSortModal() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Text(
                  'Sắp xếp danh sách món',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const Divider(),
              ...CategorySortOption.values.map(
                (opt) => ListTile(
                  leading: Icon(
                    opt.icon,
                    color: _selectedSort == opt
                        ? AppColors.orange
                        : AppColors.muted,
                  ),
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      fontWeight: _selectedSort == opt
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: _selectedSort == opt
                          ? AppColors.orangeDark
                          : AppColors.ink,
                    ),
                  ),
                  trailing: _selectedSort == opt
                      ? const Icon(Icons.check_circle, color: AppColors.orange)
                      : null,
                  onTap: () {
                    setState(() => _selectedSort = opt);
                    Navigator.pop(context);
                  },
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
    final filteredFoods = _getFilteredFoods();
    final subcategories = _getSubcategories();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.ink,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Quay lại',
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getCategoryIcon(_currentCategory),
                color: AppColors.orange,
                size: 18,
              ),
            ),
            Expanded(
              child: Text(
                _currentCategory,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${filteredFoods.length} món',
                style: const TextStyle(
                  color: AppColors.orangeDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text('Giỏ hàng có ${widget.cartCount} món'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
            icon: Badge(
              label: Text('${widget.cartCount}'),
              isLabelVisible: widget.cartCount > 0,
              backgroundColor: AppColors.orange,
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.ink,
              ),
            ),
            tooltip: 'Giỏ hàng',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.line, height: 1),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Search Box & Filter Toolbar
          SliverToBoxAdapter(child: _buildToolbar()),

          // 2. Subcategories Horizontal Scroll (if any)
          if (subcategories.length > 1)
            SliverToBoxAdapter(child: _buildSubcategoryChips(subcategories)),

          // 3. Header row: Results count & active status
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hiển thị ${filteredFoods.length} món',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  if (_onlySale)
                    InkWell(
                      onTap: () => setState(() => _onlySale = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF007F).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFF007F)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '⚡ Đang giảm giá ✕',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF0055),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 4. Food List / Grid
          if (filteredFoods.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 32),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final food = filteredFoods[index];
                  final saleItem = _getFlashSale(food.id);
                  return FoodCard(
                    food: food,
                    flashSale: saleItem,
                    isFlashSaleTimeActive: _isFlashSaleTimeActive,
                    isFavorite: widget.favorites.contains(food.id),
                    onFavorite: () => widget.onToggleFavorite(food.id),
                    onAdd: () => widget.onAddToCart(food.name),
                    onTap: () => _openFoodDetail(food),
                  );
                }, childCount: filteredFoods.length),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.63,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // SEARCH & FILTER TOOLBAR
  // ==========================================

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          // Search input
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm trong $_currentCategory...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.muted,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.orange,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Action filter row (Sort + Only Sale)
          Row(
            children: [
              // Sort Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showSortModal,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.ink,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  icon: Icon(
                    _selectedSort.icon,
                    size: 16,
                    color: AppColors.orange,
                  ),
                  label: Text(
                    _selectedSort.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Quick Sale Filter Chip
              FilterChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('⚡ ', style: TextStyle(fontSize: 12)),
                    Text(
                      'Đang giảm giá',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                selected: _onlySale,
                onSelected: (val) => setState(() => _onlySale = val),
                selectedColor: AppColors.orange.withValues(alpha: 0.15),
                backgroundColor: Colors.white,
                checkmarkColor: AppColors.orange,
                side: BorderSide(
                  color: _onlySale ? AppColors.orange : Colors.grey.shade300,
                  width: _onlySale ? 1.5 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SUBCATEGORY CHIPS
  // ==========================================

  Widget _buildSubcategoryChips(List<String> subcategories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: subcategories.map((subcat) {
          final isSelected =
              _currentCategory.toLowerCase() == subcat.toLowerCase() ||
              (_isAllCategory(_currentCategory) && _isAllCategory(subcat));

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                _getCategoryIcon(subcat),
                size: 14,
                color: isSelected ? Colors.white : AppColors.muted,
              ),
              label: Text(subcat),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _currentCategory = subcat);
                }
              },
              selectedColor: AppColors.orange,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.ink,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.orange : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // EMPTY STATE
  // ==========================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: AppColors.muted,
              size: 54,
            ),
            const SizedBox(height: 14),
            Text(
              'Không tìm thấy món ăn nào',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Không có món phù hợp với tiêu chí tìm kiếm hoặc bộ lọc hiện tại.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _onlySale = false;
                  _currentCategory = 'Tất cả';
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Xem tất cả thực đơn'),
            ),
          ],
        ),
      ),
    );
  }
}
