import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/combo_item.dart';
import '../models/flash_sale.dart';
import '../models/food_item.dart';
import '../models/food_review_item.dart';
import '../models/home_content.dart';
import 'api_exception.dart';

class FoodService {
  FoodService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers([String? token]) => {
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<List<FoodItem>> fetchFoods() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/foods'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Không thể tải thực đơn.',
          statusCode: response.statusCode,
        );
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) {
        throw const ApiException('Dữ liệu thực đơn không hợp lệ.');
      }
      return data
          .whereType<Map<String, dynamic>>()
          .map(FoodItem.fromJson)
          .toList();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Không kết nối được máy chủ để tải thực đơn.');
    }
  }

  Future<List<FlashSaleCampaign>> fetchFlashSales() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/flash-sales/active'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(FlashSaleCampaign.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ComboItem>> fetchCombos() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/foods/combos'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(ComboItem.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<FoodReviewItem>> fetchReviews({
    int? foodId,
    int limit = 50,
  }) async {
    try {
      final uri = foodId != null && foodId > 0
          ? Uri.parse(
              '${ApiConfig.baseUrl}/food-reviews?foodId=$foodId&limit=$limit',
            )
          : Uri.parse('${ApiConfig.baseUrl}/food-reviews?limit=$limit');
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      List rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map && data['reviews'] is List) {
        rawList = data['reviews'] as List;
      } else if (data is Map && data['data'] is List) {
        rawList = data['data'] as List;
      } else {
        return const [];
      }
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(FoodReviewItem.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<FoodCategory>> fetchCategories() async {
    return _fetchList(
      '/foods/categories',
      FoodCategory.fromJson,
      timeout: const Duration(seconds: 20),
    );
  }

  Future<List<HomeAnnouncement>> fetchAnnouncements(String token) async {
    return _fetchList(
      '/announcements/archive',
      HomeAnnouncement.fromJson,
      token: token,
      timeout: const Duration(seconds: 20),
    );
  }

  Future<List<HomeAdvertisement>> fetchAdvertisements() async {
    return _fetchList(
      '/advertisements?limit=20',
      HomeAdvertisement.fromJson,
      timeout: const Duration(seconds: 20),
    );
  }

  Future<int> fetchAvailableVoucherCount(String token) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/orders/vouchers/available'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) return 0;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data is List ? data.length : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markAnnouncementsRead(String token, List<int> ids) async {
    if (ids.isEmpty) return;
    final response = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/announcements/read'),
          headers: {..._headers(token), 'Content-Type': 'application/json'},
          body: jsonEncode({'ids': ids}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Không thể cập nhật trạng thái thông báo.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<T>> _fetchList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    String? token,
    required Duration timeout,
  }) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers(token))
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) return const [];
      return data.whereType<Map<String, dynamic>>().map(fromJson).toList();
    } catch (_) {
      return const [];
    }
  }
}
