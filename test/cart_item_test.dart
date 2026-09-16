import 'package:flutter_test/flutter_test.dart';
import 'package:food_mobile/models/cart_item.dart';
import 'package:food_mobile/models/food_item.dart';

void main() {
  final food = FoodItem(
    id: 10,
    name: 'Com ga',
    category: 'Do an',
    price: 65000,
    imageUrl: '',
    rating: 5,
    sold: 10,
  );

  test('uses flash sale price for cart subtotal', () {
    final item = CartItem(food: food, quantity: 2, salePrice: 49000);

    expect(item.effectivePrice, 49000);
    expect(item.subtotal, 98000);
    expect(item.hasDiscount, isTrue);
    expect(item.isCombo, isFalse);
  });

  test('keeps combo identity and combo price', () {
    final comboFood = FoodItem(
      id: -3,
      name: 'Combo trua',
      category: 'Combo',
      price: 99000,
      imageUrl: '',
      rating: 0,
      sold: 0,
    );
    final item = CartItem(food: comboFood, quantity: 2, comboId: 3);

    expect(item.comboId, 3);
    expect(item.effectivePrice, 99000);
    expect(item.subtotal, 198000);
    expect(item.isCombo, isTrue);
  });
}
