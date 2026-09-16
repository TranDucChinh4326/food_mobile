import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class OrderDetailItem {
  const OrderDetailItem({
    required this.id,
    required this.orderId,
    this.foodId,
    this.itemType = 'food',
    this.comboId,
    required this.foodName,
    required this.price,
    required this.quantity,
    required this.subtotal,
    this.foodImage,
    this.reviewId,
    this.reviewIsVisible,
  });

  final int id;
  final int orderId;
  final int? foodId;
  final String itemType;
  final int? comboId;
  final String foodName;
  final int price;
  final int quantity;
  final int subtotal;
  final String? foodImage;
  final int? reviewId;
  final int? reviewIsVisible;

  factory OrderDetailItem.fromJson(Map<String, dynamic> json) {
    String? img = json['food_image']?.toString();
    if (img != null && img.isNotEmpty && img.startsWith('/')) {
      img = 'https://food-backend-xrb9.onrender.com$img';
    }

    return OrderDetailItem(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      orderId: int.tryParse('${json['order_id'] ?? 0}') ?? 0,
      foodId: int.tryParse('${json['food_id']}'),
      itemType: '${json['item_type'] ?? 'food'}',
      comboId: int.tryParse('${json['combo_id']}'),
      foodName: '${json['food_name'] ?? 'Món ăn'}',
      price: double.tryParse('${json['price'] ?? 0}')?.round() ?? 0,
      quantity: int.tryParse('${json['quantity'] ?? 1}') ?? 1,
      subtotal: double.tryParse('${json['subtotal'] ?? 0}')?.round() ?? 0,
      foodImage: img,
      reviewId: int.tryParse('${json['review_id']}'),
      reviewIsVisible: int.tryParse('${json['review_is_visible']}'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'food_id': foodId,
    'item_type': itemType,
    'combo_id': comboId,
    'food_name': foodName,
    'price': price,
    'quantity': quantity,
    'subtotal': subtotal,
    'food_image': foodImage,
    'review_id': reviewId,
    'review_is_visible': reviewIsVisible,
  };
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.address,
    this.note,
    this.shippingFee = 0,
    this.shippingMethodId,
    this.shippingMethodName,
    this.discountCode,
    this.discountAmount = 0,
    required this.totalPrice,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.createdAt,
    this.items = const [],
  });

  final int id;
  final String customerName;
  final String phone;
  final String address;
  final String? note;
  final int shippingFee;
  final int? shippingMethodId;
  final String? shippingMethodName;
  final String? discountCode;
  final int discountAmount;
  final int totalPrice;
  final String paymentMethod;
  final String paymentStatus;
  final String status;
  final DateTime createdAt;
  final List<OrderDetailItem> items;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return OrderModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      customerName: '${json['customer_name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      address: '${json['address'] ?? ''}',
      note: json['note']?.toString(),
      shippingFee:
          double.tryParse('${json['shipping_fee'] ?? 0}')?.round() ?? 0,
      shippingMethodId: int.tryParse('${json['shipping_method_id']}'),
      shippingMethodName: json['shipping_method_name']?.toString(),
      discountCode: json['discount_code']?.toString(),
      discountAmount:
          double.tryParse('${json['discount_amount'] ?? 0}')?.round() ?? 0,
      totalPrice: double.tryParse('${json['total_price'] ?? 0}')?.round() ?? 0,
      paymentMethod: '${json['payment_method'] ?? 'cod'}',
      paymentStatus: '${json['payment_status'] ?? 'pending'}',
      status: '${json['status'] ?? 'pending'}',
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(OrderDetailItem.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_name': customerName,
    'phone': phone,
    'address': address,
    'note': note,
    'shipping_fee': shippingFee,
    'shipping_method_id': shippingMethodId,
    'shipping_method_name': shippingMethodName,
    'discount_code': discountCode,
    'discount_amount': discountAmount,
    'total_price': totalPrice,
    'payment_method': paymentMethod,
    'payment_status': paymentStatus,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
  };

  // Status mapping matching Web
  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'delivering':
        return 'Đang giao';
      case 'done':
        return 'Hoàn tất';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFE65100);
      case 'confirmed':
        return const Color(0xFF1565C0);
      case 'delivering':
        return const Color(0xFFF57C00);
      case 'done':
        return const Color(0xFF2E7D32);
      case 'cancelled':
        return const Color(0xFFC62828);
      default:
        return AppColors.muted;
    }
  }

  Color get statusBgColor {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFF3E0);
      case 'confirmed':
        return const Color(0xFFE3F2FD);
      case 'delivering':
        return const Color(0xFFFFF8E1);
      case 'done':
        return const Color(0xFFE8F5E9);
      case 'cancelled':
        return const Color(0xFFFFEBEE);
      default:
        return Colors.grey.shade100;
    }
  }

  int get stepIndex {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0; // Đã đặt, chờ duyệt
      case 'confirmed':
        return 1; // Đã xác nhận & đang chuẩn bị
      case 'delivering':
        return 2; // Đang giao
      case 'done':
        return 3; // Hoàn tất
      case 'cancelled':
        return -1; // Đã hủy
      default:
        return 0;
    }
  }

  bool get isCancellable => status.toLowerCase() == 'pending';

  String get formattedPrice {
    final digits = totalPrice.toString();
    final chunks = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      chunks.insert(0, digits.substring((end - 3).clamp(0, end), end));
    }
    return '${chunks.join('.')}đ';
  }

  String get formattedCreatedAt {
    final d = createdAt;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month/$year lúc $hour:$minute';
  }

  String get paymentMethodLabel {
    switch (paymentMethod.toLowerCase()) {
      case 'cod':
        return 'Thanh toán tiền mặt khi nhận hàng (COD)';
      case 'vietqr':
        return 'Chuyển khoản VietQR';
      case 'vnpay':
        return 'Ví điện tử VNPay';
      default:
        return paymentMethod.toUpperCase();
    }
  }
}
