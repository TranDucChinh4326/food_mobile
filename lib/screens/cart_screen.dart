import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/cart_item.dart';
import '../widgets/app_image.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    required this.items,
    required this.onUpdateQuantity,
    required this.onRemoveItem,
    required this.onClearCart,
    required this.onGoToMenu,
    required this.onCheckout,
  });

  final List<CartItem> items;
  final void Function(int foodId, int newQty) onUpdateQuantity;
  final void Function(int foodId) onRemoveItem;
  final VoidCallback onClearCart;
  final VoidCallback onGoToMenu;
  final VoidCallback onCheckout;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  int get _totalItems => widget.items.fold(0, (s, i) => s + i.quantity);
  int get _totalPrice => widget.items.fold(0, (s, i) => s + i.subtotal);
  int get _totalSaved => widget.items.fold(
    0,
    (s, i) =>
        s +
        (i.hasDiscount ? (i.food.price - i.effectivePrice) * i.quantity : 0),
  );

  String _formatPrice(int price) {
    // Định dạng: 45000 → "45.000₫"
    final formatted = price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '$formatted₫';
  }

  void _showClearConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Xóa giỏ hàng?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: const Text('Tất cả món sẽ bị xóa khỏi giỏ hàng của bạn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onClearCart();
            },
            child: const Text(
              'Xóa tất cả',
              style: TextStyle(
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: widget.items.isEmpty
                  ? FadeTransition(opacity: _fadeAnim, child: _buildEmpty())
                  : FadeTransition(opacity: _fadeAnim, child: _buildCartList()),
            ),
            if (widget.items.isNotEmpty) _buildCheckoutBar(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Header
  // ──────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
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
            child: const Icon(
              Icons.shopping_cart_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Giỏ hàng',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                if (widget.items.isNotEmpty)
                  Text(
                    '$_totalItems món · ${_formatPrice(_totalPrice)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.items.isNotEmpty)
            TextButton.icon(
              onPressed: _showClearConfirm,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: Color(0xFFE53935),
              ),
              label: const Text(
                'Xóa tất cả',
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Empty state
  // ──────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 52,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Giỏ hàng trống',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Hãy thêm những món ngon\nvào giỏ hàng để đặt ngay nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: widget.onGoToMenu,
              icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
              label: const Text(
                'Xem thực đơn',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Cart list
  // ──────────────────────────────────────────────

  Widget _buildCartList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: widget.items.length + 1, // +1 for summary card
      itemBuilder: (context, index) {
        if (index == widget.items.length) {
          return _buildSummaryCard();
        }
        final item = widget.items[index];
        return _buildCartItemCard(item);
      },
    );
  }

  Widget _buildCartItemCard(CartItem item) {
    return Dismissible(
      key: ValueKey(item.food.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Xóa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => widget.onRemoveItem(item.food.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ảnh món
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: AppImage(
                    source: item.food.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Thông tin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.food.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Nút xóa nhỏ
                        GestureDetector(
                          onTap: () => widget.onRemoveItem(item.food.id),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Giá
                    Row(
                      children: [
                        Text(
                          _formatPrice(item.effectivePrice),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.orange,
                          ),
                        ),
                        if (item.hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            _formatPrice(item.food.price),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.muted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3D00),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-${(((item.food.price - item.effectivePrice) / item.food.price) * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Bộ điều chỉnh số lượng + Tổng tiền
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Stepper
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3EE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFCCBC)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _stepperBtn(
                                icon: Icons.remove_rounded,
                                onTap: () {
                                  if (item.quantity <= 1) {
                                    widget.onRemoveItem(item.food.id);
                                  } else {
                                    widget.onUpdateQuantity(
                                      item.food.id,
                                      item.quantity - 1,
                                    );
                                  }
                                },
                                danger: item.quantity <= 1,
                              ),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${item.quantity}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                              _stepperBtn(
                                icon: Icons.add_rounded,
                                onTap: () => widget.onUpdateQuantity(
                                  item.food.id,
                                  item.quantity + 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tổng tiền item
                        Text(
                          _formatPrice(item.subtotal),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepperBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 18,
          color: danger ? const Color(0xFFE53935) : AppColors.orange,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Summary card
  // ──────────────────────────────────────────────

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tóm tắt đơn hàng',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow('Số món', '$_totalItems món', isBold: false),
          const SizedBox(height: 6),
          _summaryRow(
            'Tạm tính',
            _formatPrice(_totalPrice + _totalSaved),
            isBold: false,
          ),
          if (_totalSaved > 0) ...[
            const SizedBox(height: 6),
            _summaryRow(
              '⚡ Tiết kiệm',
              '- ${_formatPrice(_totalSaved)}',
              isBold: false,
              valueColor: const Color(0xFF0F8F61),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFFF3F4F6)),
          ),
          _summaryRow('Tổng cộng', _formatPrice(_totalPrice), isBold: true),
          const SizedBox(height: 6),
          const Text(
            '* Phí vận chuyển sẽ được tính khi xác nhận đơn',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isBold ? AppColors.ink : AppColors.muted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: valueColor ?? (isBold ? AppColors.orange : AppColors.ink),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Checkout bar
  // ──────────────────────────────────────────────

  Widget _buildCheckoutBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Tổng tiền bên trái
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tổng thanh toán',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatPrice(_totalPrice),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppColors.orange,
                  ),
                ),
                if (_totalSaved > 0)
                  Text(
                    'Tiết kiệm ${_formatPrice(_totalSaved)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0F8F61),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Nút đặt hàng
          FilledButton.icon(
            onPressed: widget.onCheckout,
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: Text(
              'Đặt hàng ($_totalItems)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
