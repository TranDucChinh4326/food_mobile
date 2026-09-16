import 'food_item.dart';

/// Đại diện cho một món trong giỏ hàng.
class CartItem {
  CartItem({
    required this.food,
    required this.quantity,
    this.salePrice, // Giá flash sale nếu có
    this.comboId,
    this.notes = '',
  });

  final FoodItem food;
  int quantity;
  int? salePrice; // null = giá thường
  final int? comboId;
  String notes;

  /// Giá hiệu lực (flash sale nếu có, ngược lại giá thường)
  int get effectivePrice => salePrice ?? food.price;

  bool get isCombo => comboId != null;

  /// Tổng tiền cho item này
  int get subtotal => effectivePrice * quantity;

  /// Có giảm giá không?
  bool get hasDiscount => salePrice != null && salePrice! < food.price;

  CartItem copyWith({int? quantity, String? notes}) {
    return CartItem(
      food: food,
      quantity: quantity ?? this.quantity,
      salePrice: salePrice,
      comboId: comboId,
      notes: notes ?? this.notes,
    );
  }
}
