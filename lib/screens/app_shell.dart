import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/auth_session.dart';
import '../models/cart_item.dart';
import '../models/combo_item.dart';
import '../models/flash_sale.dart';
import '../models/food_item.dart';
import '../models/food_review_item.dart';
import '../models/home_content.dart';
import '../services/food_service.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onSessionUpdated,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final ValueChanged<AuthSession> onSessionUpdated;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  // ── Giỏ hàng ────────────────────────────────
  final List<CartItem> _cartItems = [];

  int get _cartCount => _cartItems.fold(0, (s, i) => s + i.quantity);

  // ── Favorites ────────────────────────────────
  final Set<int> _favorites = {};

  // ── Data ─────────────────────────────────────
  final FoodService _foodService = FoodService();
  List<FoodItem> _foods = const [];
  List<FlashSaleCampaign> _flashSales = const [];
  List<ComboItem> _combos = const [];
  List<FoodReviewItem> _reviews = const [];
  List<FoodCategory> _categories = const [];
  List<HomeAnnouncement> _announcements = const [];
  List<HomeAdvertisement> _advertisements = const [];
  int _availableVoucherCount = 0;
  bool _loadingFoods = true;
  String? _foodError;

  @override
  void initState() {
    super.initState();
    _hydrateFromCache();
    _loadAllData();
  }

  void _hydrateFromCache() {
    final cachedFoods = _foodService.getCachedFoods();
    final cachedCategories = _foodService.getCachedCategories();
    final cachedCombos = _foodService.getCachedCombos();
    final cachedFlashSales = _foodService.getCachedFlashSales();
    final cachedReviews = _foodService.getCachedReviews();
    final cachedAnnouncements = _foodService.getCachedAnnouncements();
    final cachedAdvertisements = _foodService.getCachedAdvertisements();

    if (cachedFoods != null && cachedFoods.isNotEmpty) {
      _foods = cachedFoods;
      _loadingFoods = false;
    }
    if (cachedCategories != null && cachedCategories.isNotEmpty) {
      _categories = cachedCategories;
    }
    if (cachedCombos != null && cachedCombos.isNotEmpty) {
      _combos = cachedCombos;
    }
    if (cachedFlashSales != null) _flashSales = cachedFlashSales;
    if (cachedReviews != null) _reviews = cachedReviews;
    if (cachedAnnouncements != null) _announcements = cachedAnnouncements;
    if (cachedAdvertisements != null) _advertisements = cachedAdvertisements;
  }

  Future<void> _loadAllData({bool forceRefresh = false}) async {
    if (_foods.isEmpty) {
      setState(() {
        _loadingFoods = true;
        _foodError = null;
      });
    }
    try {
      final results = await Future.wait([
        _foodService.fetchFoods(forceRefresh: forceRefresh),
        _foodService.fetchFlashSales(forceRefresh: forceRefresh),
        _foodService.fetchCombos(forceRefresh: forceRefresh),
        _foodService.fetchReviews(forceRefresh: forceRefresh),
        _foodService.fetchCategories(forceRefresh: forceRefresh),
        _foodService.fetchAnnouncements(
          widget.session.token,
          forceRefresh: forceRefresh,
        ),
        _foodService.fetchAdvertisements(forceRefresh: forceRefresh),
        _foodService.fetchAvailableVoucherCount(widget.session.token),
      ]);
      if (mounted) {
        setState(() {
          _foods = results[0] as List<FoodItem>;
          _flashSales = results[1] as List<FlashSaleCampaign>;
          _combos = results[2] as List<ComboItem>;
          _reviews = results[3] as List<FoodReviewItem>;
          _categories = results[4] as List<FoodCategory>;
          _announcements = results[5] as List<HomeAnnouncement>;
          _advertisements = results[6] as List<HomeAdvertisement>;
          _availableVoucherCount = results[7] as int;
        });
      }
    } catch (error) {
      if (mounted && _foods.isEmpty) {
        setState(() => _foodError = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingFoods = false);
    }
  }

  // ──────────────────────────────────────────────
  // Cart actions
  // ──────────────────────────────────────────────

  /// Thêm một món vào giỏ. Nếu đã có thì tăng số lượng.
  void _addToCart(String foodName, {int? salePrice}) {
    final food = _foods.firstWhere(
      (f) => f.name == foodName,
      orElse: () => FoodItem(
        id: -1,
        name: foodName,
        category: '',
        price: 0,
        imageUrl: '',
        rating: 0,
        sold: 0,
      ),
    );

    setState(() {
      final existingIndex = _cartItems.indexWhere((i) => i.food.id == food.id);
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity++;
      } else {
        _cartItems.add(CartItem(food: food, quantity: 1, salePrice: salePrice));
      }
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã thêm $foodName vào giỏ hàng 🛒'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'XEM GIỎ',
            onPressed: () => setState(() => _selectedIndex = 2),
          ),
        ),
      );
  }

  void _updateCartQuantity(int foodId, int newQty) {
    setState(() {
      final idx = _cartItems.indexWhere((i) => i.food.id == foodId);
      if (idx >= 0) {
        if (newQty <= 0) {
          _cartItems.removeAt(idx);
        } else {
          _cartItems[idx].quantity = newQty;
        }
      }
    });
  }

  void _removeCartItem(int foodId) {
    setState(() => _cartItems.removeWhere((i) => i.food.id == foodId));
  }

  void _clearCart() {
    setState(() => _cartItems.clear());
  }

  void _handleCheckout() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tính năng đặt hàng đang phát triển! 🚀'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ──────────────────────────────────────────────
  // Favorites
  // ──────────────────────────────────────────────

  void _toggleFavorite(int foodId) {
    setState(() {
      _favorites.contains(foodId)
          ? _favorites.remove(foodId)
          : _favorites.add(foodId);
    });
  }

  Future<void> _markAnnouncementsRead(List<int> ids) async {
    if (ids.isEmpty) return;
    await _foodService.markAnnouncementsRead(widget.session.token, ids);
    if (!mounted) return;
    final readIds = ids.toSet();
    setState(() {
      _announcements = _announcements
          .map(
            (item) =>
                readIds.contains(item.id) ? item.copyWith(isRead: true) : item,
          )
          .toList();
    });
  }

  // ──────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screens = [
      // 0 — Trang chủ
      HomeScreen(
        foods: _foods,
        flashSales: _flashSales,
        combos: _combos,
        reviews: _reviews,
        categories: _categories,
        announcements: _announcements,
        advertisements: _advertisements,
        availableVoucherCount: _availableVoucherCount,
        loading: _loadingFoods,
        loadError: _foodError,
        onRetry: () => _loadAllData(forceRefresh: true),
        cartCount: _cartCount,
        favorites: _favorites,
        onAddToCart: (name) => _addToCart(name),
        onToggleFavorite: _toggleFavorite,
        onMarkAnnouncementsRead: _markAnnouncementsRead,
        session: widget.session,
        onSelectTab: (index) => setState(() => _selectedIndex = index),
      ),

      // 1 — Đơn hàng
      OrdersScreen(
        session: widget.session,
        onGoToMenu: () => setState(() => _selectedIndex = 0),
        onAddToCart: (name) => _addToCart(name),
      ),

      // 2 — Giỏ hàng (thay thế Yêu thích cũ)
      CartScreen(
        items: _cartItems,
        onUpdateQuantity: _updateCartQuantity,
        onRemoveItem: _removeCartItem,
        onClearCart: _clearCart,
        onGoToMenu: () => setState(() => _selectedIndex = 0),
        onCheckout: _handleCheckout,
      ),

      // 3 — Tài khoản
      AccountScreen(
        session: widget.session,
        onLogout: widget.onLogout,
        onSessionUpdated: widget.onSessionUpdated,
        onAddToCart: (name) => _addToCart(name),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
          ),
          // Tab Giỏ hàng — badge số lượng
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _cartCount > 0,
              label: Text('$_cartCount'),
              backgroundColor: AppColors.orange,
              textColor: Colors.white,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _cartCount > 0,
              label: Text('$_cartCount'),
              backgroundColor: AppColors.orange,
              textColor: Colors.white,
              child: const Icon(Icons.shopping_cart_rounded),
            ),
            label: 'Giỏ hàng',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
