import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/order_item.dart';
import 'local_cache_service.dart';

class OrderService {
  OrderService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _ordersCacheKey = 'cache_user_orders_v1';

  /// Lấy danh sách đơn hàng đã lưu trong cache cục bộ (nạp tức thì 0ms)
  List<OrderModel>? getCachedOrders() {
    final cached = LocalCacheService.read(
      _ordersCacheKey,
      maxAge: const Duration(hours: 1),
    );
    if (cached == null) return null;
    try {
      final list = jsonDecode(cached) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(OrderModel.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Gọi API GET /orders với query tìm kiếm và lọc ngày
  Future<List<OrderModel>> fetchOrders(
    String token, {
    String? q,
    String? date,
    bool forceRefresh = false,
  }) async {
    final hasFilter =
        (q != null && q.isNotEmpty) || (date != null && date.isNotEmpty);

    // Nếu không có filter và không ép buộc làm mới, kiểm tra cache trước
    if (!forceRefresh && !hasFilter) {
      final cached = getCachedOrders();
      if (cached != null) return cached;
    }

    final queryParams = <String, String>{};
    if (q != null && q.trim().isNotEmpty) {
      queryParams['q'] = q.trim();
    }
    if (date != null && date.trim().isNotEmpty) {
      queryParams['date'] = date.trim();
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/orders')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = utf8.decode(response.bodyBytes);
      final rawList = jsonDecode(body) as List<dynamic>;
      final orders = rawList
          .whereType<Map<String, dynamic>>()
          .map(OrderModel.fromJson)
          .toList();

      // Lưu cache danh sách tổng khi không có bộ lọc
      if (!hasFilter) {
        LocalCacheService.save(_ordersCacheKey, body);
      }

      return orders;
    } else {
      final body = utf8.decode(response.bodyBytes);
      try {
        final err = jsonDecode(body);
        throw Exception(err['message'] ?? 'Không thể tải danh sách đơn hàng');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Lỗi máy chủ (${response.statusCode})');
      }
    }
  }

  /// Hủy đơn hàng khi đơn còn ở trạng thái 'pending' (Chờ xác nhận)
  Future<void> cancelOrder(String token, int orderId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/cancel');
    final response = await _client.post(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      final body = utf8.decode(response.bodyBytes);
      try {
        final err = jsonDecode(body);
        throw Exception(err['message'] ?? 'Không thể hủy đơn hàng');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Lỗi hủy đơn hàng (${response.statusCode})');
      }
    }
  }
}
