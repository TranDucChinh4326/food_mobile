import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/cart_item.dart';
import '../models/food_item.dart';

class CartStorageService {
  CartStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  Future<void> _writeQueue = Future.value();

  String _key(int userId) => 'cart_items_user_$userId';

  Future<List<CartItem>> load(int userId) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => _fromJson(Map<String, dynamic>.from(item)))
          .whereType<CartItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(int userId, List<CartItem> items) async {
    final snapshot = items.map(_toJson).toList();
    _writeQueue = _writeQueue.catchError((_) {}).then((_) async {
      if (snapshot.isEmpty) {
        await _storage.delete(key: _key(userId));
      } else {
        await _storage.write(key: _key(userId), value: jsonEncode(snapshot));
      }
    });
    await _writeQueue;
  }

  Map<String, dynamic> _toJson(CartItem item) => {
    'foodId': item.food.id,
    'name': item.food.name,
    'category': item.food.category,
    'price': item.food.price,
    'imageUrl': item.food.imageUrl,
    'rating': item.food.rating,
    'sold': item.food.sold,
    'stockQuantity': item.food.stockQuantity,
    'quantity': item.quantity,
    'salePrice': item.salePrice,
    'comboId': item.comboId,
    'notes': item.notes,
  };

  CartItem? _fromJson(Map<String, dynamic> json) {
    final foodId = int.tryParse('${json['foodId']}');
    final quantity = int.tryParse('${json['quantity']}');
    final price = int.tryParse('${json['price']}');
    if (foodId == null || quantity == null || quantity <= 0 || price == null) {
      return null;
    }
    return CartItem(
      food: FoodItem(
        id: foodId,
        name: '${json['name'] ?? ''}',
        category: '${json['category'] ?? ''}',
        price: price,
        imageUrl: '${json['imageUrl'] ?? ''}',
        rating: double.tryParse('${json['rating']}') ?? 0,
        sold: int.tryParse('${json['sold']}') ?? 0,
        stockQuantity: int.tryParse('${json['stockQuantity']}') ?? 99,
      ),
      quantity: quantity,
      salePrice: int.tryParse('${json['salePrice']}'),
      comboId: int.tryParse('${json['comboId']}'),
      notes: '${json['notes'] ?? ''}',
    );
  }
}
