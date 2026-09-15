import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/flash_sale.dart';
import '../models/food_item.dart';
import '../models/food_review_item.dart';
import '../services/food_service.dart';
import '../widgets/app_image.dart';

class FoodDetailScreen extends StatefulWidget {
  const FoodDetailScreen({
    super.key,
    required this.food,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onAddToCart,
    this.allFoods = const [],
    this.flashSales = const [],
  });

  final FoodItem food;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final void Function(
    String foodName,
    int quantity,
    String notes,
    int totalPrice,
  )
  onAddToCart;
  final List<FoodItem> allFoods;
  final List<FlashSaleCampaign> flashSales;

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  int _quantity = 1;
  final Set<String> _selectedOptions = {};
  final TextEditingController _notesController = TextEditingController();

  final FoodService _foodService = FoodService();
  List<FoodReviewItem> _reviews = const [];
  bool _loadingReviews = true;
  String _selectedRatingFilter = 'all';

  Timer? _countdownTimer;
  Duration _remainingDuration = Duration.zero;

  // 3 Tùy chọn thêm đồng bộ chuẩn Web Bếp 1979
  final Map<String, int> _webOptions = const {
    'Thêm phô mai': 15000,
    'Thêm topping': 25000,
    'Không hành tây': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _initFlashSaleCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  FlashSaleItem? get _flashSaleItem {
    for (final campaign in widget.flashSales) {
      for (final item in campaign.items) {
        if (item.foodId == widget.food.id) {
          return item;
        }
      }
    }
    return null;
  }

  FlashSaleCampaign? get _flashCampaign {
    final item = _flashSaleItem;
    if (item == null) return null;
    for (final campaign in widget.flashSales) {
      if (campaign.items.any((i) => i.foodId == widget.food.id)) {
        return campaign;
      }
    }
    return null;
  }

  void _initFlashSaleCountdown() {
    final campaign = _flashCampaign;
    final endsAt = campaign?.endsAt == null
        ? null
        : DateTime.tryParse(campaign!.endsAt!.replaceAll(' ', 'T'));
    if (endsAt != null) {
      final diff = endsAt.difference(DateTime.now());
      _remainingDuration = diff.isNegative ? Duration.zero : diff;
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final nowDiff = endsAt.difference(DateTime.now());
        if (nowDiff.isNegative) {
          timer.cancel();
          if (mounted) setState(() => _remainingDuration = Duration.zero);
        } else {
          if (mounted) setState(() => _remainingDuration = nowDiff);
        }
      });
    }
  }

  String _formatTimer(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _foodService.fetchReviews(
        foodId: widget.food.id,
        limit: 50,
      );
      if (mounted) setState(() => _reviews = reviews);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  bool _isDrink(FoodItem food) {
    final cat = food.category.toLowerCase();
    final name = food.name.toLowerCase();
    return cat.contains('uống') ||
        cat.contains('nước') ||
        cat.contains('giải khát') ||
        name.contains('trà') ||
        name.contains('cà phê') ||
        name.contains('sinh tố') ||
        name.contains('nước ép') ||
        name.contains('coca') ||
        name.contains('pepsi');
  }

  int get _optionsTotal {
    int total = 0;
    for (final opt in _selectedOptions) {
      total += _webOptions[opt] ?? 0;
    }
    return total;
  }

  int get _currentUnitPrice {
    final sale = _flashSaleItem;
    final basePrice = sale != null ? sale.salePrice : widget.food.price;
    return basePrice + _optionsTotal;
  }

  int get _totalPrice => _currentUnitPrice * _quantity;

  String _formatPrice(int value) {
    final digits = value.toString();
    final chunks = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      chunks.insert(0, digits.substring((end - 3).clamp(0, end), end));
    }
    return chunks.join('.');
  }

  void _submitAddToCart() {
    final noteParts = <String>[];
    if (_selectedOptions.isNotEmpty) {
      noteParts.add('Tùy chọn: ${_selectedOptions.join(", ")}');
    }
    if (_notesController.text.trim().isNotEmpty) {
      noteParts.add(_notesController.text.trim());
    }

    final finalNotes = noteParts.join(' | ');
    widget.onAddToCart(widget.food.name, _quantity, finalNotes, _totalPrice);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Đã thêm $_quantity phần "${widget.food.name}" vào giỏ hàng!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<FoodItem> get _recommendedFoods {
    final isCurrentDrink = _isDrink(widget.food);
    // Gợi ý món khác loại: nếu đang xem món ăn -> gợi ý đồ uống, ngược lại
    final preferred = widget.allFoods.where((item) {
      if (item.id == widget.food.id) return false;
      if (item.stockQuantity <= 0) return false;
      return isCurrentDrink ? !_isDrink(item) : _isDrink(item);
    }).toList();

    final fallback = widget.allFoods.where((item) {
      if (item.id == widget.food.id) return false;
      if (item.stockQuantity <= 0) return false;
      return !preferred.any((p) => p.id == item.id);
    }).toList();

    return [...preferred, ...fallback].take(4).toList();
  }

  List<FoodReviewItem> get _filteredReviews {
    if (_selectedRatingFilter == 'all') return _reviews;
    final star = int.tryParse(_selectedRatingFilter);
    if (star == null) return _reviews;
    return _reviews.where((r) => r.rating == star).toList();
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final sale = _flashSaleItem;
    final isSale = sale != null;

    final baseOriginalPrice = sale != null
        ? sale.originalPrice
        : (food.oldPrice ?? food.price);
    final currentPrice = sale != null ? sale.salePrice : food.price;
    final hasDiscount = baseOriginalPrice > currentPrice;
    final discountPercent = hasDiscount
        ? (((baseOriginalPrice - currentPrice) / baseOriginalPrice) * 100)
              .round()
        : 0;
    final savings = hasDiscount ? (baseOriginalPrice - currentPrice) : 0;
    final isDrink = _isDrink(food);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0x205C3018),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: Color(0xFF201814),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Chi tiết món ăn',
          style: TextStyle(
            color: Color(0xFF201814),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              widget.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: widget.isFavorite
                  ? const Color(0xFFFF007F)
                  : const Color(0xFF7D6255),
              size: 24,
            ),
            onPressed: widget.onToggleFavorite,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Breadcrumb Bar chuẩn Web
                _buildBreadcrumb(food),
                const SizedBox(height: 12),

                // 2. Hero Image Gallery với hào quang Neon Flash Sale
                _buildHeroImage(food, isSale),
                const SizedBox(height: 14),

                // 3. Perspectives Grid (3 góc nhìn sản phẩm chuẩn Web)
                _buildPerspectivesGrid(isDrink),
                const SizedBox(height: 18),

                // 4. Tags Row: Category Pill + Flash Sale Pill
                _buildTagsRow(food, isSale),
                const SizedBox(height: 10),

                // 5. Title
                Text(
                  food.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF201814),
                    height: 1.22,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),

                // 6. Stats Row (Stars, Rating, Sold, Reviews) & Stock badge
                _buildStatsAndStockRow(food),
                const SizedBox(height: 14),

                // 7. Flash Sale Box Banner (nếu đang Flash Sale)
                if (isSale) ...[
                  _buildFlashSaleBanner(sale, discountPercent, savings),
                  const SizedBox(height: 14),
                ],

                // 8. Price Display
                _buildPriceSection(
                  currentPrice,
                  baseOriginalPrice,
                  hasDiscount,
                  isSale,
                ),
                const SizedBox(height: 18),

                // 9. Mô tả sản phẩm (Bullet points màu cam chuẩn Web)
                _buildDescriptionSection(food, isDrink),
                const SizedBox(height: 20),

                // 10. Tùy chọn thêm (Options chuẩn Web)
                _buildWebOptionsSection(),
                const SizedBox(height: 18),

                // 11. Ghi chú cho nhà bếp (Optional)
                _buildNotesSection(),
                const SizedBox(height: 24),

                // 12. Gợi ý dùng kèm / Có thể bạn muốn thêm (Suggestions)
                if (_recommendedFoods.isNotEmpty) ...[
                  _buildSuggestionsSection(isDrink),
                  const SizedBox(height: 24),
                ],

                // 13. Đánh giá & Nhận xét với thanh phân bổ 5 sao (Rating Breakdown)
                _buildReviewsSection(food),
              ],
            ),
          ),

          // 14. Sticky Bottom Actions (Bộ chọn số lượng con nhộng 999px + Nút thêm giỏ)
          _buildStickyBottomBar(food),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUB-COMPONENTS
  // ===========================================================================

  /// 1. Breadcrumb: Trang chủ > [Danh mục] > [Tên món]
  Widget _buildBreadcrumb(FoodItem food) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: const Text(
              'Trang chủ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A6F62),
              ),
            ),
          ),
          const Text(
            '>',
            style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
          ),
          Text(
            food.category,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A6F62),
            ),
          ),
          const Text(
            '>',
            style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
          ),
          Text(
            food.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF201814),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Image Gallery với Neon Flash Sale Aura
  Widget _buildHeroImage(FoodItem food, bool isSale) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSale
            ? [
                BoxShadow(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFFFF007F).withValues(alpha: 0.32),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF502A18).withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Container(
        padding: isSale ? const EdgeInsets.all(3.5) : EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSale
              ? const LinearGradient(
                  colors: [
                    Color(0xFF00F0FF),
                    Color(0xFF9D00FF),
                    Color(0xFFFF007F),
                    Color(0xFFFFEA00),
                    Color(0xFF00FF88),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSale ? 13 : 16),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 1 / 0.78,
                child: AppImage(
                  source: food.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFFFFF3EB),
                    child: const Center(
                      child: Icon(
                        Icons.restaurant_rounded,
                        size: 64,
                        color: Color(0xFFFF7A1A),
                      ),
                    ),
                  ),
                ),
              ),
              if (isSale)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF007F), Color(0xFFFF5500)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF007F).withValues(alpha: 0.6),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text(
                      '⚡ FLASH SALE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 3. Perspectives Grid (3 góc nhìn sản phẩm chuẩn Web)
  Widget _buildPerspectivesGrid(bool isDrink) {
    final items = isDrink
        ? [
            {
              'title': 'Vị chính',
              'text': 'Dễ uống, hậu vị gọn và hợp khi dùng trong ngày.',
            },
            {
              'title': 'Dùng kèm',
              'text':
                  'Hợp với món mặn, món chiên hoặc các phần ăn nhiều tinh bột.',
            },
            {
              'title': 'Cảm giác',
              'text': 'Làm mới khẩu vị, giúp bữa ăn nhẹ hơn và cân bằng hơn.',
            },
          ]
        : [
            {
              'title': 'Hương vị',
              'text': 'Đậm đà vừa phải, dễ ăn và hợp nhiều khẩu vị.',
            },
            {
              'title': 'Kết cấu',
              'text': 'Ưu tiên độ mềm, độ nóng và cảm giác ngon khi giao tới.',
            },
            {
              'title': 'Dùng kèm',
              'text': 'Ngon hơn khi gọi thêm nước uống hoặc món phụ phù hợp.',
            },
          ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFAF7), Color(0xFFFFF4ED)],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF0D8CB)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF572D18).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF24140F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['text']!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF765F54),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 4. Tags Row: Category pill + Flash Sale pill
  Widget _buildTagsRow(FoodItem food, bool isSale) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1E8),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFFFD6C2)),
          ),
          child: Text(
            food.category.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFC14F0A),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
        if (isSale) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF007F), Color(0xFFFF4500)],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF007F).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              '🔥 Đang Flash Sale',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 6. Stats & Stock
  Widget _buildStatsAndStockRow(FoodItem food) {
    final stock = food.stockQuantity;
    final isAvailable = stock > 0;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF0DFD5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFF8A00),
                  size: 17,
                ),
                const SizedBox(width: 4),
                Text(
                  '${food.rating > 0 ? food.rating.toStringAsFixed(1) : "5.0"} sao',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF8A00),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${food.sold} lượt mua',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6F584D),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${_reviews.length} đánh giá',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6F584D),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isAvailable
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isAvailable
                  ? const Color(0xFFA5D6A7)
                  : const Color(0xFFFFCDD2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isAvailable
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                isAvailable ? 'Còn $stock' : 'Hết hàng',
                style: TextStyle(
                  color: isAvailable
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 7. Flash Sale Box Banner
  Widget _buildFlashSaleBanner(
    FlashSaleItem sale,
    int discountPercent,
    int savings,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF0F5), Color(0xFFFFF6EE), Color(0xFFF0F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF007F).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF007F).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        colors: [Color(0xFFFF007F), Color(0xFFFF4500)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '⚡ FLASH SALE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Giảm -$discountPercent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              if (_remainingDuration > Duration.zero)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFFFD1DC)),
                  ),
                  child: Row(
                    children: [
                      const Text('⏰ ', style: TextStyle(fontSize: 11)),
                      Text(
                        _formatTimer(_remainingDuration),
                        style: const TextStyle(
                          color: Color(0xFFFF0055),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            children: [
              const Text(
                '🔥 Ưu đãi số lượng có hạn',
                style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
              ),
              if (savings > 0)
                Text(
                  '• Tiết kiệm ngay ${_formatPrice(savings)}đ',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF0055),
                  ),
                ),
              if (sale.remaining != null)
                Text(
                  '• Còn lại ${sale.remaining} suất',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF201814),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 8. Price Section
  Widget _buildPriceSection(
    int currentPrice,
    int originalPrice,
    bool hasDiscount,
    bool isSale,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSale ? const Color(0xFFFFF0F5) : const Color(0xFFFFF4ED),
        borderRadius: BorderRadius.circular(8),
        border: isSale
            ? const Border(left: BorderSide(color: Color(0xFFFF007F), width: 4))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '${_formatPrice(currentPrice)}đ',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isSale ? const Color(0xFFFF0055) : const Color(0xFFFF5722),
            ),
          ),
          if (hasDiscount) ...[
            const SizedBox(width: 12),
            Text(
              '${_formatPrice(originalPrice)}đ',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF9E9E9E),
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 9. Mô tả sản phẩm (Bullet points màu cam chuẩn Web)
  Widget _buildDescriptionSection(FoodItem food, bool isDrink) {
    final baseDesc =
        (food.description != null && food.description!.trim().isNotEmpty)
        ? food.description!.trim()
        : '${food.name} được Bếp 1979 chọn để phục vụ nhanh, dễ ăn và hợp khẩu vị hằng ngày.';

    final lines = [
      baseDesc,
      isDrink
          ? 'Hương vị được cân bằng để uống riêng vẫn ngon, dùng kèm món chính cũng không bị gắt.'
          : 'Khẩu phần được cân chỉnh vừa đủ no, hợp cho bữa trưa, bữa tối hoặc gọi thêm khi đi nhóm.',
      'Món thuộc nhóm ${food.category}, được ưu tiên giữ màu sắc và kết cấu hấp dẫn khi giao đến tay bạn.',
      'Bếp 1979 khuyến khích dùng ngay sau khi nhận để cảm nhận rõ hương vị, độ nóng/lạnh và phần topping.',
      isDrink
          ? 'Có thể kết hợp cùng món mặn, món chiên hoặc cơm/phở để bữa ăn đỡ ngấy hơn.'
          : 'Có thể gọi kèm nước uống hoặc món phụ để bữa ăn trọn vị hơn.',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1DED3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mô tả sản phẩm',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF24140F),
            ),
          ),
          const SizedBox(height: 12),
          ...lines.map((line) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF7A1A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF5F4A3F),
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 10. Tùy chọn thêm (Options chuẩn Web)
  Widget _buildWebOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tùy chọn thêm',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF201814),
          ),
        ),
        const SizedBox(height: 10),
        ..._webOptions.entries.map((entry) {
          final title = entry.key;
          final price = entry.value;
          final isSelected = _selectedOptions.contains(title);

          return InkWell(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedOptions.remove(title);
                } else {
                  _selectedOptions.add(title);
                }
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFFF4ED)
                    : const Color(0xFFFFF8F3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF7A1A)
                      : const Color(0xFFF0DFD5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: isSelected
                            ? const Color(0xFFFF7A1A)
                            : const Color(0xFFAAAAAA),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: const Color(0xFF3C2D26),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    price > 0 ? '+${_formatPrice(price)}đ' : 'Miễn phí',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? const Color(0xFFA64008)
                          : const Color(0xFF8A6F62),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 11. Notes Section
  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ghi chú cho nhà bếp',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF201814),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Ví dụ: Ít dầu mỡ, nhiều sốt chấm, để riêng rau...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFF0DFD5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFF0DFD5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFFF7A1A),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 12. Gợi ý dùng kèm (Suggestions Section)
  Widget _buildSuggestionsSection(bool isDrink) {
    final title = isDrink ? '✨ Có thể bạn muốn thêm' : '✨ Gợi ý dùng kèm';
    final subtitle = isDrink
        ? 'Món ăn bán chạy để đi cùng'
        : 'Nước uống hợp với món này';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF201814),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7D6255),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _recommendedFoods.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final rec = _recommendedFoods[index];
              return _buildSuggestionCard(rec);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(FoodItem rec) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => FoodDetailScreen(
              food: rec,
              isFavorite: false,
              onToggleFavorite: () {},
              onAddToCart: widget.onAddToCart,
              allFoods: widget.allFoods,
              flashSales: widget.flashSales,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 145,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF0DFD5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF502A18).withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(9),
              ),
              child: AspectRatio(
                aspectRatio: 1 / 0.72,
                child: AppImage(
                  source: rec.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFFFFF3EB),
                    child: const Center(
                      child: Icon(
                        Icons.restaurant,
                        color: Color(0xFFFF7A1A),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF201814),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFF8A00),
                        size: 13,
                      ),
                      Text(
                        ' ${rec.rating > 0 ? rec.rating.toStringAsFixed(1) : "5.0"}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Còn ${rec.stockQuantity}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF7D6255),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_formatPrice(rec.price)}đ',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF5722),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          widget.onAddToCart(rec.name, 1, '', rec.price);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã thêm "${rec.name}" vào giỏ!'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A1A),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            '+ Thêm',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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
    );
  }

  /// 13. Đánh giá & Nhận xét với thanh phân bổ 5 sao (Rating Breakdown)
  Widget _buildReviewsSection(FoodItem food) {
    final totalReviews = _reviews.length;
    final avgRating = totalReviews > 0
        ? _reviews.map((r) => r.rating).reduce((a, b) => a + b) / totalReviews
        : (food.rating > 0 ? food.rating : 5.0);

    // Tính số lượng từng sao (5, 4, 3, 2, 1)
    final Map<int, int> starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final rev in _reviews) {
      final s = rev.rating.clamp(1, 5);
      starCounts[s] = (starCounts[s] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đánh giá & Nhận xét',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF201814),
          ),
        ),
        const SizedBox(height: 12),

        // Rating Summary Box (Score + Breakdown Bars)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF0DFD5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF502A18).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cột điểm trung bình
              SizedBox(
                width: 95,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF201814),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (_) => const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFF8A00),
                          size: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dựa trên $totalReviews đánh giá',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF8A6F62),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 90, color: const Color(0xFFF0DFD5)),
              const SizedBox(width: 12),

              // Thanh phân bổ 5 sao (Breakdown bars)
              Expanded(
                child: Column(
                  children: [5, 4, 3, 2, 1].map((star) {
                    final count = starCounts[star] ?? 0;
                    final pct = totalReviews > 0 ? (count / totalReviews) : 0.0;
                    final isFilterActive = _selectedRatingFilter == '$star';

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedRatingFilter = isFilterActive
                              ? 'all'
                              : '$star';
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Row(
                          children: [
                            Text(
                              '$star★',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isFilterActive
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isFilterActive
                                    ? const Color(0xFFFF5722)
                                    : const Color(0xFF7D6255),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6.5,
                                  backgroundColor: const Color(0xFFF0DFD5),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isFilterActive
                                        ? const Color(0xFFFF5722)
                                        : const Color(0xFFFF8A00),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 22,
                              child: Text(
                                '$count',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF8A6F62),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Filter Chips (Tất cả, 5 sao, 4 sao, 3 sao...)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip('all', 'Tất cả ($totalReviews)'),
              _buildFilterChip('5', '5 sao (${starCounts[5]})'),
              _buildFilterChip('4', '4 sao (${starCounts[4]})'),
              _buildFilterChip('3', '3 sao (${starCounts[3]})'),
              _buildFilterChip('2', '2 sao (${starCounts[2]})'),
              _buildFilterChip('1', '1 sao (${starCounts[1]})'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Danh sách nhận xét
        if (_loadingReviews)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                color: AppColors.orange,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_filteredReviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF0DFD5)),
            ),
            child: const Center(
              child: Text(
                'Chưa có đánh giá nào phù hợp với bộ lọc này.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF8A6F62)),
              ),
            ),
          )
        else
          Column(
            children: _filteredReviews
                .map((rev) => _buildReviewCard(rev))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedRatingFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedRatingFilter = value),
        selectedColor: const Color(0xFFFF5722),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF5F4A3F),
        ),
        side: BorderSide(
          color: isSelected ? const Color(0xFFFF5722) : const Color(0xFFF0DFD5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildReviewCard(FoodReviewItem rev) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF0DFD5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFFFF1E8),
                backgroundImage: rev.avatar != null && rev.avatar!.isNotEmpty
                    ? NetworkImage(rev.avatar!)
                    : null,
                child: rev.avatar == null || rev.avatar!.isEmpty
                    ? Text(
                        rev.customerName.isNotEmpty
                            ? rev.customerName[0].toUpperCase()
                            : 'K',
                        style: const TextStyle(
                          color: Color(0xFFFF7A1A),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          rev.customerName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF201814),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.check,
                                size: 10,
                                color: Color(0xFF2E7D32),
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Đã mua',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: List.generate(
                        rev.rating.clamp(1, 5),
                        (_) => const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFF8A00),
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (rev.createdAt != null && rev.createdAt!.isNotEmpty)
                Text(
                  rev.createdAt!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFFAAAAAA),
                  ),
                ),
            ],
          ),
          if (rev.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rev.comment,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF3C2D26),
                height: 1.4,
              ),
            ),
          ],
          if (rev.adminReply != null && rev.adminReply!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC14F0A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rev.adminReply!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF3C2D26),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 14. Sticky Bottom Action Bar
  Widget _buildStickyBottomBar(FoodItem food) {
    final stock = food.stockQuantity;
    final isAvailable = stock > 0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5C3018).withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Row(
          children: [
            // Bộ chọn số lượng con nhộng 999px chuẩn Web CSS
            Container(
              height: 48,
              width: 144,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFFEDBC8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB84C19).withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nút trừ (-) kem ấm
                  InkWell(
                    onTap: _quantity > 1 && isAvailable
                        ? () => setState(() => _quantity--)
                        : null,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3EC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x38EB4102),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x1FEB4102),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.remove,
                          size: 18,
                          color: Color(0xFFEB4102),
                        ),
                      ),
                    ),
                  ),
                  // Số lượng hiển thị
                  Text(
                    '$_quantity',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF241914),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  // Nút cộng (+) cam 3D viền đồng tâm
                  InkWell(
                    onTap: _quantity < stock && isAvailable
                        ? () => setState(() => _quantity++)
                        : null,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF7E36),
                            Color(0xFFFF5213),
                            Color(0xFFEB4102),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF0480A)
                                .withValues(alpha: 0.38),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.65),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.add, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Nút Thêm vào giỏ hàng gradient cam chuẩn Web
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: isAvailable
                      ? const LinearGradient(
                          colors: [Color(0xFFFF5722), Color(0xFFFF8A1D)],
                        )
                      : null,
                  color: !isAvailable ? const Color(0xFFD9C8BD) : null,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isAvailable
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF5722)
                                .withValues(alpha: 0.32),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isAvailable ? _submitAddToCart : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Center(
                      child: Text(
                        isAvailable
                            ? 'Thêm vào giỏ • ${_formatPrice(_totalPrice)}đ'
                            : 'Hết hàng',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
