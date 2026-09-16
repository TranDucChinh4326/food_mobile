import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/auth_session.dart';
import '../models/cart_item.dart';
import '../models/checkout_model.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../widgets/app_image.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    required this.items,
    this.session,
    required this.onUpdateQuantity,
    required this.onRemoveItem,
    required this.onClearCart,
    required this.onGoToMenu,
    required this.onOrderSuccess,
  });

  final List<CartItem> items;
  final AuthSession? session;
  final void Function(int foodId, int newQty) onUpdateQuantity;
  final void Function(int foodId) onRemoveItem;
  final VoidCallback onClearCart;
  final VoidCallback onGoToMenu;
  final VoidCallback onOrderSuccess;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // Form controllers
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _noteController;
  late final TextEditingController _discountCodeController;

  // Saved addresses
  List<UserAddress> _savedAddresses = [];
  UserAddress? _selectedSavedAddress;
  bool _loadingAddresses = false;

  // Shipping methods & quotes
  List<ShippingMethod> _shippingMethods = [];
  ShippingMethod? _selectedShippingMethod;
  ShippingQuote? _shippingQuote;
  bool _loadingShippingMethods = true;
  bool _loadingShippingQuote = false;
  Timer? _shippingQuoteDebounce;

  // Vouchers
  List<UserVoucher> _ownedVouchers = [];
  UserVoucher? _selectedVoucher;
  DiscountPreview? _appliedDiscount;
  bool _isApplyingDiscount = false;
  String? _discountError;

  // Order submission
  bool _isSubmittingOrder = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    final user = widget.session?.user;
    _nameController = TextEditingController(text: user?.fullname ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _noteController = TextEditingController();
    _discountCodeController = TextEditingController();

    _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant CartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.token != widget.session?.token) {
      _loadInitialData();
    }
    // If cart items changed and a discount is applied, refresh discount preview
    if (oldWidget.items != widget.items && _appliedDiscount != null) {
      _reapplyCurrentDiscount();
    }
  }

  @override
  void dispose() {
    _shippingQuoteDebounce?.cancel();
    _fadeCtrl.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _discountCodeController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // Initial Data Loading
  // ──────────────────────────────────────────────

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadShippingMethods(),
      _loadSavedAddresses(),
      _loadOwnedVouchers(),
    ]);
  }

  Future<void> _loadShippingMethods() async {
    try {
      final methods = await _orderService.fetchShippingMethods();
      if (!mounted) return;
      setState(() {
        _shippingMethods = methods;
        _loadingShippingMethods = false;
        if (methods.isNotEmpty) {
          _selectedShippingMethod = methods.first;
        }
      });
      if (_addressController.text.trim().isNotEmpty) {
        _triggerShippingQuoteRefresh();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingShippingMethods = false);
    }
  }

  Future<void> _loadSavedAddresses() async {
    final token = widget.session?.token;
    if (token == null) return;
    setState(() => _loadingAddresses = true);
    try {
      final addresses = await _authService.fetchAddresses(token);
      if (!mounted) return;
      setState(() {
        _savedAddresses = addresses;
        _loadingAddresses = false;

        // Auto select default address if available
        final defaultAddress = addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => addresses.isNotEmpty
              ? addresses.first
              : const UserAddress(
                  id: 0,
                  label: '',
                  receiverName: '',
                  phone: '',
                  address: '',
                  isDefault: false,
                ),
        );

        if (defaultAddress.id != 0) {
          _selectedSavedAddress = defaultAddress;
          if (_nameController.text.isEmpty &&
              defaultAddress.receiverName.isNotEmpty) {
            _nameController.text = defaultAddress.receiverName;
          }
          if (_phoneController.text.isEmpty &&
              defaultAddress.phone.isNotEmpty) {
            _phoneController.text = defaultAddress.phone;
          }
          if (_addressController.text.isEmpty &&
              defaultAddress.address.isNotEmpty) {
            _addressController.text = defaultAddress.address;
          }
        }
      });

      if (_addressController.text.trim().isNotEmpty) {
        _triggerShippingQuoteRefresh();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  Future<void> _loadOwnedVouchers() async {
    final token = widget.session?.token;
    if (token == null) return;
    try {
      final vouchers = await _authService.fetchVouchers(token);
      if (mounted) {
        setState(() => _ownedVouchers = vouchers);
      }
    } catch (_) {}
  }

  // ──────────────────────────────────────────────
  // Shipping Quote Calculation
  // ──────────────────────────────────────────────

  void _triggerShippingQuoteRefresh() {
    _shippingQuoteDebounce?.cancel();
    _shippingQuoteDebounce = Timer(const Duration(milliseconds: 600), () {
      _fetchShippingQuote();
    });
  }

  Future<void> _fetchShippingQuote() async {
    final address = _addressController.text.trim();
    final method = _selectedShippingMethod;
    if (address.isEmpty || method == null) {
      if (mounted) setState(() => _shippingQuote = null);
      return;
    }

    if (mounted) setState(() => _loadingShippingQuote = true);
    try {
      final quote = await _orderService.getShippingQuote(
        shippingMethodId: method.id,
        customerAddress: address,
      );
      if (mounted) {
        setState(() {
          _shippingQuote = quote;
          _loadingShippingQuote = false;
        });
        if (_appliedDiscount != null) {
          _reapplyCurrentDiscount();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _shippingQuote = null;
          _loadingShippingQuote = false;
        });
      }
    }
  }

  // ──────────────────────────────────────────────
  // Voucher & Discount Application
  // ──────────────────────────────────────────────

  Future<void> _applyDiscount({String? code, int? userDiscountId}) async {
    final token = widget.session?.token;
    if (token == null) {
      _showToast('Vui lòng đăng nhập để áp dụng mã giảm giá', isError: true);
      return;
    }

    final rawCode = code ?? _discountCodeController.text.trim();
    if (rawCode.isEmpty && userDiscountId == null) {
      setState(
        () => _discountError = 'Vui lòng nhập mã giảm giá hoặc chọn voucher',
      );
      return;
    }

    setState(() {
      _isApplyingDiscount = true;
      _discountError = null;
    });

    try {
      final preview = await _orderService.previewDiscount(
        token: token,
        discountCode: userDiscountId != null ? null : rawCode,
        userDiscountId: userDiscountId,
        itemsSubtotal: _itemsSubtotal,
        shippingFee: _effectiveShippingFee,
        shippingMethodId: _selectedShippingMethod?.id ?? 1,
        customerAddress: _addressController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _appliedDiscount = preview;
          _isApplyingDiscount = false;
          _discountError = null;
        });
        _showToast('Áp dụng mã ${preview.code} thành công! 🎉');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appliedDiscount = null;
          _isApplyingDiscount = false;
          _discountError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _reapplyCurrentDiscount() {
    if (_appliedDiscount != null) {
      _applyDiscount(
        code: _appliedDiscount!.userDiscountId == null
            ? _appliedDiscount!.code
            : null,
        userDiscountId: _appliedDiscount!.userDiscountId,
      );
    }
  }

  void _removeDiscount() {
    setState(() {
      _appliedDiscount = null;
      _selectedVoucher = null;
      _discountCodeController.clear();
      _discountError = null;
    });
    _showToast('Đã gỡ mã giảm giá');
  }

  // ──────────────────────────────────────────────
  // Price Computations
  // ──────────────────────────────────────────────

  int get _totalItems => widget.items.fold(0, (s, i) => s + i.quantity);
  int get _itemsSubtotal => widget.items.fold(0, (s, i) => s + i.subtotal);
  int get _totalSavedFromFlashSale => widget.items.fold(
    0,
    (s, i) =>
        s +
        (i.hasDiscount ? (i.food.price - i.effectivePrice) * i.quantity : 0),
  );

  int get _effectiveShippingFee {
    if (_shippingQuote != null) {
      return _shippingQuote!.fee;
    }
    return _selectedShippingMethod?.fee ?? 15000;
  }

  int get _discountAmount => _appliedDiscount?.discountAmount ?? 0;

  int get _finalTotal =>
      (_itemsSubtotal + _effectiveShippingFee - _discountAmount).clamp(
        0,
        999999999,
      );

  String _formatPrice(num price) {
    final intPrice = price.round();
    final formatted = intPrice.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '$formatted₫';
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFD32F2F)
              : const Color(0xFF2E7D32),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ──────────────────────────────────────────────
  // Order Submission (COD Delivery)
  // ──────────────────────────────────────────────

  Future<void> _submitOrder() async {
    final token = widget.session?.token;
    if (token == null) {
      _showToast('Vui lòng đăng nhập để đặt món', isError: true);
      return;
    }

    if (widget.items.isEmpty) {
      _showToast('Giỏ hàng đang trống. Hãy chọn món trước nhé!', isError: true);
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      _showToast('Vui lòng nhập họ và tên người nhận', isError: true);
      return;
    }

    if (phone.isEmpty || phone.length < 9) {
      _showToast(
        'Vui lòng nhập số điện thoại hợp lệ để giao hàng',
        isError: true,
      );
      return;
    }

    if (address.isEmpty || address.length < 5) {
      _showToast('Vui lòng nhập địa chỉ giao hàng cụ thể', isError: true);
      return;
    }

    final shippingMethodId = _selectedShippingMethod?.id;
    if (shippingMethodId == null) {
      _showToast('Vui lòng chọn hình thức giao hàng', isError: true);
      return;
    }

    setState(() => _isSubmittingOrder = true);

    try {
      final cartItemsPayload = widget.items.map((item) {
        if (item.isCombo) {
          return {
            'comboId': item.comboId,
            'quantity': item.quantity,
            'type': 'combo',
          };
        }
        return {
          'foodId': item.food.id,
          'quantity': item.quantity,
          'type': 'food',
        };
      }).toList();

      final res = await _orderService.createOrder(
        token: token,
        customerName: name,
        customerPhone: phone,
        customerAddress: address,
        customerNote: _noteController.text.trim(),
        paymentMethod: 'cod', // Nhận hàng mới trả tiền
        shippingMethodId: shippingMethodId,
        discountCode: _appliedDiscount?.userDiscountId != null
            ? null
            : _appliedDiscount?.code,
        userDiscountId: _appliedDiscount?.userDiscountId,
        items: cartItemsPayload,
      );

      final orderData = res['order'] as Map<String, dynamic>?;
      final orderId = orderData?['id'] ?? res['id'];

      if (!mounted) return;
      setState(() => _isSubmittingOrder = false);

      _showOrderSuccessDialog(orderId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingOrder = false);
      _showToast(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _showOrderSuccessDialog(dynamic orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF2E7D32),
                size: 48,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Đặt hàng thành công!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            if (orderId != null)
              Text(
                'Mã đơn hàng: #$orderId',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange,
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Đơn hàng của bạn đã được chuyển tới Bếp 1979. Shipper sẽ gọi cho bạn khi giao món!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: AppColors.orange,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Thanh toán khi nhận hàng (COD)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onOrderSuccess();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Theo dõi đơn hàng',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: widget.items.isEmpty
                  ? FadeTransition(opacity: _fadeAnim, child: _buildEmpty())
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: _buildCheckoutContent(),
                    ),
            ),
            if (widget.items.isNotEmpty) _buildCheckoutBottomBar(),
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
                  'Giỏ hàng & Đặt món',
                  style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                if (widget.items.isNotEmpty)
                  Text(
                    '$_totalItems món · Tạm tính ${_formatPrice(_itemsSubtotal)}',
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
                'Xóa hết',
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
  // Empty State
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
              'Hãy thêm những món ngon của Bếp 1979\nvào giỏ hàng để thưởng thức nhé!',
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
  // Main Checkout Content
  // ──────────────────────────────────────────────

  Widget _buildCheckoutContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // 1. Danh sách món ăn
        _buildSectionCard(
          title: 'Món ăn đã chọn ($_totalItems)',
          icon: Icons.fastfood_rounded,
          iconColor: AppColors.orange,
          action: TextButton.icon(
            onPressed: widget.onGoToMenu,
            icon: const Icon(Icons.add, size: 16, color: AppColors.orange),
            label: const Text(
              'Thêm món',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.orange,
              ),
            ),
          ),
          child: Column(children: widget.items.map(_buildCartItemRow).toList()),
        ),
        const SizedBox(height: 14),

        // 2. Thông tin giao hàng
        _buildSectionCard(
          title: 'Thông tin giao hàng',
          icon: Icons.location_on_rounded,
          iconColor: const Color(0xFFE53935),
          child: _buildDeliveryAddressSection(),
        ),
        const SizedBox(height: 14),

        // 3. Hình thức giao hàng
        _buildSectionCard(
          title: 'Hình thức giao hàng',
          icon: Icons.delivery_dining_rounded,
          iconColor: const Color(0xFF1976D2),
          child: _buildShippingMethodsSection(),
        ),
        const SizedBox(height: 14),

        // 4. Khuyến mãi & Voucher
        _buildSectionCard(
          title: 'Khuyến mãi & Voucher',
          icon: Icons.confirmation_number_rounded,
          iconColor: const Color(0xFF7B1FA2),
          child: _buildVoucherSection(),
        ),
        const SizedBox(height: 14),

        // 5. Phương thức thanh toán (COD mặc định)
        _buildSectionCard(
          title: 'Phương thức thanh toán',
          icon: Icons.payments_rounded,
          iconColor: const Color(0xFF2E7D32),
          child: _buildPaymentMethodSection(),
        ),
        const SizedBox(height: 14),

        // 6. Chi tiết thanh toán
        _buildSectionCard(
          title: 'Chi tiết thanh toán',
          icon: Icons.receipt_rounded,
          iconColor: AppColors.ink,
          child: _buildPaymentSummarySection(),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Card Container Helper
  // ──────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    Widget? action,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (action != null) action,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 1. Cart Item Row
  // ──────────────────────────────────────────────

  Widget _buildCartItemRow(CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 58,
              height: 58,
              child: AppImage(source: item.food.imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.food.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatPrice(item.effectivePrice),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.orange,
                      ),
                    ),
                    if (item.hasDiscount) ...[
                      const SizedBox(width: 6),
                      Text(
                        _formatPrice(item.food.price),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Stepper
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3EE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCCBC)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    if (item.quantity <= 1) {
                      widget.onRemoveItem(item.food.id);
                    } else {
                      widget.onUpdateQuantity(item.food.id, item.quantity - 1);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      Icons.remove_rounded,
                      size: 16,
                      color: item.quantity <= 1
                          ? const Color(0xFFE53935)
                          : AppColors.orange,
                    ),
                  ),
                ),
                SizedBox(
                  width: 26,
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () =>
                      widget.onUpdateQuantity(item.food.id, item.quantity + 1),
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: AppColors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              _formatPrice(item.subtotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 2. Delivery Address Section
  // ──────────────────────────────────────────────

  Widget _buildDeliveryAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Saved address chips
        if (_savedAddresses.isNotEmpty) ...[
          const Text(
            'Chọn địa chỉ đã lưu:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _savedAddresses.map((addr) {
                final isSelected = _selectedSavedAddress?.id == addr.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          addr.isDefault
                              ? Icons.star_rounded
                              : Icons.home_rounded,
                          size: 15,
                          color: isSelected ? Colors.white : AppColors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(addr.label.isNotEmpty ? addr.label : 'Địa chỉ'),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.orange,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.ink,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSavedAddress = addr;
                          if (addr.receiverName.isNotEmpty) {
                            _nameController.text = addr.receiverName;
                          }
                          if (addr.phone.isNotEmpty) {
                            _phoneController.text = addr.phone;
                          }
                          _addressController.text = addr.address;
                        } else {
                          _selectedSavedAddress = null;
                        }
                      });
                      _triggerShippingQuoteRefresh();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Họ tên
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Họ và tên người nhận *',
            hintText: 'VD: Nguyễn Văn A',
            prefixIcon: const Icon(Icons.person_outline, size: 20),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Số điện thoại
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Số điện thoại liên hệ *',
            hintText: 'VD: 0901234567',
            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Địa chỉ chi tiết
        TextField(
          controller: _addressController,
          maxLines: 2,
          onChanged: (_) => _triggerShippingQuoteRefresh(),
          decoration: InputDecoration(
            labelText: 'Địa chỉ giao hàng *',
            hintText: 'Số nhà, tên đường, phường/xã, quận/huyện',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Icon(Icons.place_outlined, size: 20),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Ghi chú
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
            labelText: 'Ghi chú cho shipper / quán (tuỳ chọn)',
            hintText: 'VD: Giao giờ trưa, gọi trước khi đến...',
            prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // 3. Shipping Methods Section
  // ──────────────────────────────────────────────

  Widget _buildShippingMethodsSection() {
    if (_loadingShippingMethods) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_shippingMethods.isEmpty) {
      return const Text(
        'Chưa cấu hình hình thức giao hàng.',
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      );
    }

    return Column(
      children: _shippingMethods.map((method) {
        final isSelected = _selectedShippingMethod?.id == method.id;
        final fee =
            (_shippingQuote != null &&
                _shippingQuote!.shippingMethodId == method.id)
            ? _shippingQuote!.fee
            : method.fee;

        return InkWell(
          onTap: () {
            setState(() => _selectedShippingMethod = method);
            _triggerShippingQuoteRefresh();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFF7F2) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.orange : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Radio<int>(
                  value: method.id,
                  groupValue: _selectedShippingMethod?.id,
                  activeColor: AppColors.orange,
                  onChanged: (val) {
                    setState(() => _selectedShippingMethod = method);
                    _triggerShippingQuoteRefresh();
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      if (method.estimatedTime.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Thời gian: ${method.estimatedTime}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_loadingShippingQuote && isSelected)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    fee == 0 ? 'Miễn phí' : _formatPrice(fee),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? AppColors.orange : AppColors.ink,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ──────────────────────────────────────────────
  // 4. Voucher & Discount Section
  // ──────────────────────────────────────────────

  Widget _buildVoucherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Already applied voucher banner
        if (_appliedDiscount != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đã áp dụng: ${_appliedDiscount!.code}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        _appliedDiscount!.applyTo == 'shipping'
                            ? 'Giảm phí giao hàng: -${_formatPrice(_appliedDiscount!.discountAmount)}'
                            : 'Giảm tiền món: -${_formatPrice(_appliedDiscount!.discountAmount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFC62828),
                    size: 18,
                  ),
                  onPressed: _removeDiscount,
                  tooltip: 'Gỡ voucher',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Input manual code + Apply button
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _discountCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Nhập mã giảm giá (VD: BEP1979)',
                  prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _isApplyingDiscount ? null : () => _applyDiscount(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isApplyingDiscount
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Áp dụng',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
            ),
          ],
        ),

        // Error message if any
        if (_discountError != null) ...[
          const SizedBox(height: 6),
          Text(
            _discountError!,
            style: const TextStyle(
              color: Color(0xFFD32F2F),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],

        // Wallet Vouchers Picker Button
        if (_ownedVouchers.isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _showOwnedVouchersSheet,
            icon: const Icon(
              Icons.wallet_giftcard_rounded,
              size: 17,
              color: AppColors.orange,
            ),
            label: Text(
              'Chọn từ ví voucher (${_ownedVouchers.length} có sẵn)',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: AppColors.ink,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              side: BorderSide(color: AppColors.orange.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showOwnedVouchersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ví Voucher của bạn',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _ownedVouchers.length,
                itemBuilder: (context, index) {
                  final v = _ownedVouchers[index];
                  final isSelected =
                      _appliedDiscount?.userDiscountId == v.userDiscountId;
                  final isEligible = _itemsSubtotal >= v.minOrder;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isEligible
                          ? Colors.white
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.orange
                            : (isEligible
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade200),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isEligible
                                ? const Color(0xFFFFF3E0)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            v.applyTo == 'shipping'
                                ? Icons.local_shipping_outlined
                                : Icons.discount_outlined,
                            color: isEligible
                                ? AppColors.orange
                                : Colors.grey.shade400,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.name.isNotEmpty ? v.name : v.code,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: isEligible
                                      ? AppColors.ink
                                      : Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                v.minOrder > 0
                                    ? 'Đơn tối thiểu: ${_formatPrice(v.minOrder)}'
                                    : 'Không giới hạn đơn tối thiểu',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.muted,
                                ),
                              ),
                              if (!isEligible) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Cần thêm ${_formatPrice(v.minOrder - _itemsSubtotal)} để áp dụng',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFE53935),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: isEligible
                              ? () {
                                  Navigator.pop(ctx);
                                  _applyDiscount(
                                    userDiscountId: v.userDiscountId,
                                  );
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: isSelected
                                ? const Color(0xFF2E7D32)
                                : AppColors.orange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            isSelected ? 'Đang dùng' : 'Áp dụng',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 5. Payment Method Section (COD Mặc định)
  // ──────────────────────────────────────────────

  Widget _buildPaymentMethodSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBE7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE775)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF33691E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Thanh toán khi nhận hàng (COD)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Color(0xFF2E7D32),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'Trả tiền mặt trực tiếp cho tài xế khi nhận món ăn nóng hổi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF33691E),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 6. Payment Summary Section
  // ──────────────────────────────────────────────

  Widget _buildPaymentSummarySection() {
    return Column(
      children: [
        _summaryRow('Tổng số lượng món', '$_totalItems phần'),
        const SizedBox(height: 8),
        _summaryRow('Tạm tính tiền món', _formatPrice(_itemsSubtotal)),
        if (_totalSavedFromFlashSale > 0) ...[
          const SizedBox(height: 8),
          _summaryRow(
            '⚡ Tiết kiệm Flash Sale',
            '- ${_formatPrice(_totalSavedFromFlashSale)}',
            valueColor: const Color(0xFF0F8F61),
          ),
        ],
        const SizedBox(height: 8),
        _summaryRow(
          'Phí giao hàng',
          _effectiveShippingFee == 0
              ? 'Miễn phí'
              : _formatPrice(_effectiveShippingFee),
        ),
        if (_appliedDiscount != null &&
            _appliedDiscount!.discountAmount > 0) ...[
          const SizedBox(height: 8),
          _summaryRow(
            'Voucher giảm (${_appliedDiscount!.code})',
            '- ${_formatPrice(_appliedDiscount!.discountAmount)}',
            valueColor: const Color(0xFF0F8F61),
          ),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
        _summaryRow(
          'Tổng thanh toán',
          _formatPrice(_finalTotal),
          isBold: true,
          valueColor: AppColors.orange,
        ),
      ],
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
            fontSize: isBold ? 17 : 13.5,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: valueColor ?? (isBold ? AppColors.orange : AppColors.ink),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Fixed Bottom Checkout Bar
  // ──────────────────────────────────────────────

  Widget _buildCheckoutBottomBar() {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tổng thanh toán (COD)',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatPrice(_finalTotal),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.orange,
                  ),
                ),
                if (_discountAmount > 0)
                  Text(
                    'Đã giảm ${_formatPrice(_discountAmount)}',
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
          FilledButton.icon(
            onPressed: _isSubmittingOrder ? null : _submitOrder,
            icon: _isSubmittingOrder
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: Text(
              _isSubmittingOrder ? 'Đang gửi...' : 'Xác nhận đặt hàng',
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
