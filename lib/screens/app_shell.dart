import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/auth_session.dart';
import '../models/combo_item.dart';
import '../models/flash_sale.dart';
import '../models/food_item.dart';
import '../models/food_review_item.dart';
import '../models/home_content.dart';
import '../services/food_service.dart';
import 'account_screen.dart';
import 'home_screen.dart';
import 'placeholder_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session, required this.onLogout});

  final AuthSession session;
  final Future<void> Function() onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  int _cartCount = 0;
  final Set<int> _favorites = {};
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
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _loadingFoods = true;
      _foodError = null;
    });
    try {
      final results = await Future.wait([
        _foodService.fetchFoods(),
        _foodService.fetchFlashSales(),
        _foodService.fetchCombos(),
        _foodService.fetchReviews(),
        _foodService.fetchCategories(),
        _foodService.fetchAnnouncements(widget.session.token),
        _foodService.fetchAdvertisements(),
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
      if (mounted) setState(() => _foodError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingFoods = false);
    }
  }

  void _addToCart(String foodName) {
    setState(() => _cartCount++);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã thêm $foodName vào giỏ hàng'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'XEM GIỎ', onPressed: () {}),
        ),
      );
  }

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

  @override
  Widget build(BuildContext context) {
    final screens = [
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
        onRetry: _loadAllData,
        cartCount: _cartCount,
        favorites: _favorites,
        onAddToCart: _addToCart,
        onToggleFavorite: _toggleFavorite,
        onMarkAnnouncementsRead: _markAnnouncementsRead,
      ),
      const PlaceholderScreen(
        icon: Icons.receipt_long_outlined,
        title: 'Đơn hàng của bạn',
        message: 'Các đơn đang xử lý và lịch sử mua hàng sẽ hiển thị tại đây.',
      ),
      const PlaceholderScreen(
        icon: Icons.favorite_outline,
        title: 'Món đã yêu thích',
        message: 'Đăng nhập để đồng bộ danh sách món yêu thích với website.',
      ),
      AccountScreen(session: widget.session, onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Yêu thích',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.small(
              onPressed: () {},
              tooltip: 'Hỗ trợ',
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              child: const Icon(Icons.support_agent),
            )
          : null,
    );
  }
}
