import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/auth_session.dart';
import '../models/order_item.dart';
import '../services/order_service.dart';
import '../widgets/app_image.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    this.session,
    required this.onGoToMenu,
    required this.onAddToCart,
  });

  final AuthSession? session;
  final VoidCallback onGoToMenu;
  final ValueChanged<String> onAddToCart;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderService _orderService = OrderService();
  final TextEditingController _searchController = TextEditingController();

  List<OrderModel> _allOrders = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedTab = 'all'; // all, pending, delivering, done, cancelled
  String _searchQuery = '';
  DateTime? _selectedDate;
  final Set<int> _expandedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _loadInitialOrders();
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.token != widget.session?.token) {
      _loadInitialOrders();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadInitialOrders() {
    if (widget.session == null) {
      setState(() {
        _allOrders = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    // 1. Tải nhanh từ cache cục bộ (0ms)
    final cached = _orderService.getCachedOrders();
    if (cached != null && cached.isNotEmpty) {
      _allOrders = cached;
      _isLoading = false;
    }

    // 2. Đồng bộ từ server
    _fetchOrdersFromServer(forceRefresh: false);
  }

  Future<void> _fetchOrdersFromServer({bool forceRefresh = false}) async {
    if (widget.session == null) return;
    if (_allOrders.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final dateStr = _selectedDate != null
          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
          : null;

      final fetched = await _orderService.fetchOrders(
        widget.session!.token,
        q: _searchQuery.isNotEmpty ? _searchQuery : null,
        date: dateStr,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _allOrders = fetched;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_allOrders.isEmpty) {
            _errorMessage = e.toString().replaceFirst('Exception: ', '');
          }
        });
      }
    }
  }

  List<OrderModel> get _filteredOrders {
    return _allOrders.where((order) {
      // Lọc theo Tab trạng thái
      if (_selectedTab == 'pending') {
        if (order.status != 'pending') return false;
      } else if (_selectedTab == 'delivering') {
        if (order.status != 'delivering' && order.status != 'confirmed') {
          return false;
        }
      } else if (_selectedTab == 'done') {
        if (order.status != 'done') return false;
      } else if (_selectedTab == 'cancelled') {
        if (order.status != 'cancelled') return false;
      }

      // Lọc theo từ khóa tìm kiếm (mã đơn, người nhận, sđt, địa chỉ)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchId = order.id.toString().contains(q);
        final matchName = order.customerName.toLowerCase().contains(q);
        final matchPhone = order.phone.contains(q);
        final matchAddress = order.address.toLowerCase().contains(q);
        final matchItems = order.items.any(
          (i) => i.foodName.toLowerCase().contains(q),
        );
        if (!matchId &&
            !matchName &&
            !matchPhone &&
            !matchAddress &&
            !matchItems) {
          return false;
        }
      }

      // Lọc theo ngày đặt
      if (_selectedDate != null) {
        final d = order.createdAt;
        if (d.year != _selectedDate!.year ||
            d.month != _selectedDate!.month ||
            d.day != _selectedDate!.day) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Đếm số lượng đơn cho từng badge
  int _countForTab(String tab) {
    if (tab == 'all') return _allOrders.length;
    if (tab == 'pending') {
      return _allOrders.where((o) => o.status == 'pending').length;
    }
    if (tab == 'delivering') {
      return _allOrders
          .where((o) => o.status == 'delivering' || o.status == 'confirmed')
          .length;
    }
    if (tab == 'done') {
      return _allOrders.where((o) => o.status == 'done').length;
    }
    if (tab == 'cancelled') {
      return _allOrders.where((o) => o.status == 'cancelled').length;
    }
    return 0;
  }

  String _formatPrice(int value) {
    final digits = value.toString();
    final chunks = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      chunks.insert(0, digits.substring((end - 3).clamp(0, end), end));
    }
    return '${chunks.join('.')}đ';
  }

  Future<void> _handleCancelOrder(OrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text('⚠️', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Xác nhận hủy đơn hàng',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn hủy đơn hàng #DH${order.id} không?\nSau khi hủy, đơn không thể hoàn tác.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.ink,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Không hủy',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Đồng ý hủy',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _orderService.cancelOrder(widget.session!.token, order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã hủy đơn hàng #DH${order.id} thành công!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      _fetchOrdersFromServer(forceRefresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  void _handleReorder(OrderModel order) {
    int count = 0;
    for (final item in order.items) {
      for (var i = 0; i < item.quantity; i++) {
        widget.onAddToCart(item.foodName);
        count++;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã thêm $count món từ đơn #DH${order.id} vào giỏ hàng! 🛒',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.orange,
      ),
    );
  }

  Future<void> _pickFilterDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2023),
      lastDate: now,
      helpText: 'CHỌN NGÀY ĐẶT HÀNG',
      confirmText: 'ÁP DỤNG',
      cancelText: 'HỦY',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchOrdersFromServer(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.orange,
          onRefresh: () => _fetchOrdersFromServer(forceRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Tiêu đề chuẩn Web
              SliverToBoxAdapter(child: _buildHeader()),

              // 2. Tabs lọc trạng thái đơn hàng (Có đếm badge)
              SliverToBoxAdapter(child: _buildStatusTabs()),

              // 3. Bộ lọc tìm kiếm & ngày
              SliverToBoxAdapter(child: _buildFilterBar()),

              // 4. Danh sách đơn hàng hoặc trạng thái trống
              if (widget.session == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildNotLoggedInState(),
                )
              else if (_isLoading && _allOrders.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.orange),
                  ),
                )
              else if (_errorMessage != null && _allOrders.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(),
                )
              else if (_filteredOrders.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyOrdersState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final order = _filteredOrders[index];
                      return _buildOrderCard(order);
                    }, childCount: _filteredOrders.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. HEADER (Chuẩn Web) ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ĐƠN HÀNG CỦA TÔI',
                    style: TextStyle(
                      color: AppColors.orange,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Lịch sử đặt hàng',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Theo dõi tiến trình giao món hoặc đặt lại món yêu thích.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: widget.onGoToMenu,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🍽️', style: TextStyle(fontSize: 13)),
                SizedBox(width: 4),
                Text(
                  'Đặt thêm món',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. STATUS TABS (Chuẩn Web kèm badge số lượng) ---
  Widget _buildStatusTabs() {
    final tabs = [
      {'key': 'all', 'label': 'Tất cả đơn'},
      {'key': 'pending', 'label': '⏳ Chờ xác nhận'},
      {'key': 'delivering', 'label': '🚚 Đang giao'},
      {'key': 'done', 'label': '✅ Hoàn tất'},
      {'key': 'cancelled', 'label': '❌ Đã hủy'},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = _selectedTab == tab['key'];
            final count = _countForTab(tab['key']!);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedTab = tab['key']!),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.orange
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.orange : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tab['label']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF374151),
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- 3. FILTER BAR (Tìm kiếm & Chọn ngày) ---
  Widget _buildFilterBar() {
    final dateDisplay = _selectedDate != null
        ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          // Ô tìm kiếm
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tìm theo mã đơn, người nhận, SĐT...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12.5,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Nút chọn ngày
          InkWell(
            onTap: _pickFilterDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _selectedDate != null
                    ? const Color(0xFFFFF3E0)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedDate != null
                      ? AppColors.orange
                      : AppColors.line,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: _selectedDate != null
                        ? AppColors.orange
                        : AppColors.muted,
                  ),
                  if (dateDisplay != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      dateDisplay,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedDate = null);
                        _fetchOrdersFromServer(forceRefresh: true);
                      },
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. ORDER CARD (Tái hiện 100% chi tiết chuẩn Web) ---
  Widget _buildOrderCard(OrderModel order) {
    final isExpanded = _expandedOrderIds.contains(order.id);
    final displayedItems = isExpanded
        ? order.items
        : order.items.take(3).toList();
    final hasMore = order.items.length > 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. Header đơn hàng: Mã đơn, Thời gian & Huy hiệu trạng thái
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.receipt_rounded,
                            size: 16,
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '#DH${order.id}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order.formattedCreatedAt,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Huy hiệu trạng thái chuẩn web
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: order.statusBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: order.statusColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: order.statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // B. Stepper tiến trình 4 bước (Chuẩn Web: Đã đặt -> Đã xác nhận -> Đang giao -> Hoàn tất)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: _buildOrderStepper(order),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // C. Danh sách món ăn trong đơn
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                ...displayedItems.map((item) => _buildOrderItemRow(item)),

                // Nút thu gọn / xem thêm nếu > 3 món
                if (hasMore)
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedOrderIds.remove(order.id);
                        } else {
                          _expandedOrderIds.add(order.id);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isExpanded
                                ? 'Thu gọn ▴'
                                : 'Xem thêm ${order.items.length - 3} món khác ▾',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // D. Thông tin giao hàng & thanh toán
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.person_pin_circle_outlined,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${order.customerName} - ${order.phone}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.paymentMethodLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
                if (order.note != null && order.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.edit_note_outlined,
                        size: 16,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ghi chú: ${order.note}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // E. Tổng tiền & Phí ship
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Column(
              children: [
                if (order.shippingFee > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Phí giao hàng:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          '+${_formatPrice(order.shippingFee)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if (order.discountAmount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Giảm giá (${order.discountCode ?? 'Voucher'}):',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        Text(
                          '-${_formatPrice(order.discountAmount)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng thanh toán:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      order.formattedPrice,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // F. Action Buttons: Hủy đơn & Đặt lại đơn này
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (order.isCancellable) ...[
                  OutlinedButton(
                    onPressed: () => _handleCancelOrder(order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFFFCDD2)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '❌ Hủy đơn',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton(
                  onPressed: () => _handleReorder(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.replay_rounded, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Đặt lại đơn này',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
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
    );
  }

  // Row hiển thị món ăn trong đơn
  Widget _buildOrderItemRow(OrderDetailItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: item.foodImage != null && item.foodImage!.isNotEmpty
                  ? AppImage(source: item.foodImage!, fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFFFFF3E0),
                      child: const Center(
                        child: Text('🍲', style: TextStyle(fontSize: 20)),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.foodName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatPrice(item.price)} × ${item.quantity}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            _formatPrice(item.subtotal),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  // Thanh tiến trình 4 bước chuẩn Web
  Widget _buildOrderStepper(OrderModel order) {
    if (order.status == 'cancelled') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFCDD2)),
        ),
        child: const Row(
          children: [
            Text('❌', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Đơn hàng này đã bị hủy.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC62828),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final steps = [
      {'title': 'Đã đặt', 'idx': 0},
      {'title': 'Đã duyệt', 'idx': 1},
      {'title': 'Đang giao', 'idx': 2},
      {'title': 'Hoàn tất', 'idx': 3},
    ];

    final currentStep = order.stepIndex;

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Đường kẻ nối
          final stepBefore = index ~/ 2;
          final isPassed = currentStep > stepBefore;
          return Expanded(
            child: Container(
              height: 2.5,
              color: isPassed ? AppColors.orange : const Color(0xFFE5E7EB),
            ),
          );
        } else {
          // Vòng tròn bước
          final stepIdx = index ~/ 2;
          final isDone = currentStep >= stepIdx;
          final isCurrent = currentStep == stepIdx;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.orange : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone ? AppColors.orange : const Color(0xFFD1D5DB),
                    width: isCurrent ? 2.5 : 1.5,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${stepIdx + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[stepIdx]['title'] as String,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  color: isDone ? AppColors.orange : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          );
        }
      }),
    );
  }

  // --- TRẠNG THÁI TRỐNG & ĐĂNG NHẬP ---
  Widget _buildEmptyOrdersState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🧾', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'Chưa có đơn hàng nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty || _selectedDate != null
                  ? 'Không tìm thấy đơn phù hợp với bộ lọc hiện tại.'
                  : 'Bạn chưa đặt đơn hàng nào tại Bếp 1979.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: widget.onGoToMenu,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Khám phá thực đơn ngay 🍲',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotLoggedInState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'Đăng nhập để xem đơn hàng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Vui lòng đăng nhập tài khoản để tra cứu lịch sử đặt hàng và theo dõi tiến trình giao món.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.muted,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Đã có lỗi xảy ra khi tải đơn hàng',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchOrdersFromServer(forceRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
              ),
              child: const Text(
                'Thử lại',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
