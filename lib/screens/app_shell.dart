import 'dart:async';

import 'package:flutter/foundation.dart';
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
import '../services/cart_storage_service.dart';
import '../services/local_cache_service.dart';
import '../services/notification_service.dart';
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
  int _ordersRefreshKey = 0;
  final Set<int> _visitedTabs = {0};

  void _selectTab(int index) {
    setState(() {
      _visitedTabs.add(index);
      _selectedIndex = index;
    });
  }

  // ── Giỏ hàng ────────────────────────────────
  final List<CartItem> _cartItems = [];
  final CartStorageService _cartStorage = CartStorageService();

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
    unawaited(_hydrateFromCache());
    _restoreCart();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _restoreCart() async {
    final items = await _cartStorage.load(widget.session.user.id);
    if (!mounted || items.isEmpty) return;
    setState(() {
      _cartItems
        ..clear()
        ..addAll(items);
    });
  }

  void _persistCart() {
    unawaited(_cartStorage.save(widget.session.user.id, _cartItems));
  }

  Future<void> _hydrateFromCache() async {
    final paths = [
      LocalCacheService.dataCachePath,
      LocalCacheService.imageCachePath,
    ];
    final cached = await compute(_readHomeCache, paths);
    if (!mounted) return;

    final cachedFoods = cached[0] as List<FoodItem>?;
    final cachedCategories = cached[1] as List<FoodCategory>?;
    final cachedCombos = cached[2] as List<ComboItem>?;
    final cachedFlashSales = cached[3] as List<FlashSaleCampaign>?;
    final cachedReviews = cached[4] as List<FoodReviewItem>?;
    final cachedAnnouncements = cached[5] as List<HomeAnnouncement>?;
    final cachedAdvertisements = cached[6] as List<HomeAdvertisement>?;

    setState(() {
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
      if (cachedAdvertisements != null) {
        _advertisements = cachedAdvertisements;
      }
    });

    await _loadAllData();
  }

  Future<void> _loadAllData({bool forceRefresh = false}) async {
    if (_foods.isEmpty) {
      setState(() {
        _loadingFoods = true;
        _foodError = null;
      });
    }
    try {
      final token = widget.session.token;
      final paths = [
        LocalCacheService.dataCachePath,
        LocalCacheService.imageCachePath,
      ];
      final results = await compute(_fetchHomeData, <Object>[
        token,
        forceRefresh,
        ...paths,
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
  void _addToCart(String foodName, {int? salePrice, ComboItem? combo}) {
    if (combo != null) {
      final comboFood = FoodItem(
        id: -combo.id,
        name: combo.name,
        category: 'Combo',
        price: combo.price,
        imageUrl: combo.image,
        rating: 0,
        sold: 0,
      );
      setState(() {
        final existingIndex = _cartItems.indexWhere(
          (item) => item.comboId == combo.id,
        );
        if (existingIndex >= 0) {
          _cartItems[existingIndex].quantity++;
        } else {
          _cartItems.add(
            CartItem(food: comboFood, quantity: 1, comboId: combo.id),
          );
        }
      });
      _persistCart();
      _showAddedToCartMessage(combo.name);
      return;
    }

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

    salePrice ??= _activeSalePriceFor(food.id);

    setState(() {
      final existingIndex = _cartItems.indexWhere((i) => i.food.id == food.id);
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity++;
        _cartItems[existingIndex].salePrice = salePrice;
      } else {
        _cartItems.add(CartItem(food: food, quantity: 1, salePrice: salePrice));
      }
    });

    _persistCart();

    _showAddedToCartMessage(foodName);
  }

  int? _activeSalePriceFor(int foodId) {
    for (final campaign in _flashSales) {
      for (final item in campaign.items) {
        if (item.foodId == foodId && item.salePrice > 0) {
          return item.salePrice;
        }
      }
    }
    return null;
  }

  void _showAddedToCartMessage(String foodName) {
    // Gửi system notification thay SnackBar
    NotificationService.instance.showAddedToCart(foodName);
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
    _persistCart();
  }

  void _removeCartItem(int foodId) {
    setState(() => _cartItems.removeWhere((i) => i.food.id == foodId));
    _persistCart();
  }

  void _clearCart() {
    setState(() => _cartItems.clear());
    _persistCart();
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
        onAddComboToCart: (combo) => _addToCart(combo.name, combo: combo),
        onToggleFavorite: _toggleFavorite,
        onMarkAnnouncementsRead: _markAnnouncementsRead,
        session: widget.session,
        onSelectTab: _selectTab,
      ),

      // 1 — Đơn hàng
      if (_visitedTabs.contains(1))
        OrdersScreen(
          session: widget.session,
          refreshKey: _ordersRefreshKey,
          onGoToMenu: () => _selectTab(0),
          onAddToCart: (name) => _addToCart(name),
        )
      else
        const SizedBox.shrink(),

      // 2 — Giỏ hàng (tính phí ship, voucher, giao hàng COD)
      if (_visitedTabs.contains(2))
        CartScreen(
          items: _cartItems,
          session: widget.session,
          onUpdateQuantity: _updateCartQuantity,
          onRemoveItem: _removeCartItem,
          onClearCart: _clearCart,
          onGoToMenu: () => _selectTab(0),
          onOrderSuccess: () {
            _clearCart();
            setState(() {
              _ordersRefreshKey++;
              _visitedTabs.add(1);
              _selectedIndex = 1;
            });
          },
        )
      else
        const SizedBox.shrink(),

      // 3 — Tài khoản
      if (_visitedTabs.contains(3))
        AccountScreen(
          session: widget.session,
          onLogout: widget.onLogout,
          onSessionUpdated: widget.onSessionUpdated,
          onAddToCart: (name) => _addToCart(name),
        )
      else
        const SizedBox.shrink(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
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

List<Object?> _readHomeCache(List<String> paths) {
  LocalCacheService.initializeFromPaths(paths[0], paths[1]);
  final service = FoodService();
  return [
    service.getCachedFoods(),
    service.getCachedCategories(),
    service.getCachedCombos(),
    service.getCachedFlashSales(),
    service.getCachedReviews(),
    service.getCachedAnnouncements(),
    service.getCachedAdvertisements(),
  ];
}

Future<List<Object>> _fetchHomeData(List<Object> arguments) async {
  final token = arguments[0] as String;
  final forceRefresh = arguments[1] as bool;
  LocalCacheService.initializeFromPaths(
    arguments[2] as String,
    arguments[3] as String,
  );
  final service = FoodService();
  return Future.wait<Object>([
    service.fetchFoods(forceRefresh: forceRefresh),
    service.fetchFlashSales(forceRefresh: forceRefresh),
    service.fetchCombos(forceRefresh: forceRefresh),
    service.fetchReviews(forceRefresh: forceRefresh),
    service.fetchCategories(forceRefresh: forceRefresh),
    service.fetchAnnouncements(token, forceRefresh: forceRefresh),
    service.fetchAdvertisements(forceRefresh: forceRefresh),
    service.fetchAvailableVoucherCount(token),
  ]);
}
