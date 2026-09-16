import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/combo_item.dart';
import '../models/flash_sale.dart';
import '../models/food_item.dart';
import '../models/food_review_item.dart';
import '../models/home_content.dart';
import 'api_exception.dart';
import 'local_cache_service.dart';

class FoodService {
  FoodService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers([String? token]) => {
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  // ================= SYNCHRONOUS CACHE HYDRATION =================
  // Used on app startup to load cached resources in 0 milliseconds

  List<FoodItem>? getCachedFoods() {
    final raw = LocalCacheService.read('foods_cache');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! List) return null;
      return data
          .whereType<Map<String, dynamic>>()
          .map(FoodItem.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  List<FoodCategory>? getCachedCategories() {
    final raw = LocalCacheService.read('categories_cache');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! List) return null;
      return data
          .whereType<Map<String, dynamic>>()
          .map(FoodCategory.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  List<ComboItem>? getCachedCombos() {
    final raw = LocalCacheService.read('combos_cache');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! List) return null;
      return data
          .whereType<Map<String, dynamic>>()
          .map(ComboItem.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  List<FlashSaleCampaign>? getCachedFlashSales() {
    final raw = LocalCacheService.read('flash_sales_cache');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! List) return null;
      return data
          .whereType<Map<String, dynamic>>()
          .map(FlashSaleCampaign.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  List<FoodReviewItem>? getCachedReviews() {
    final raw = LocalCacheService.read('reviews_cache');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      List rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map && data['reviews'] is List) {
        rawList = data['reviews'] as List;
      } else if (data is Map && data['data'] is List) {
        rawList = data['data'] as List;
      } else {
        return null;
      }
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(FoodReviewItem.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  List<HomeAdvertisement>? getCachedAdvertisements() {
    final raw = LocalCacheService.read('advertisements_cache');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! List) return null;
      return data
          .whereType<Map<String, dynamic>>()
          .map(HomeAdvertisement.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  List<HomeAnnouncement>? getCachedAnnouncements() {
    final raw = LocalCacheService.read('announcements_cache');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! List) return null;
      return data
          .whereType<Map<String, dynamic>>()
          .map(HomeAnnouncement.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ================= ASYNC SMART FETCH WITH CACHE =================

  Future<List<FoodItem>> fetchFoods({bool forceRefresh = false}) async {
    // 1. Check if cache is fresh within 5 minutes (like web FOODS_CACHE_TTL)
    if (!forceRefresh &&
        LocalCacheService.isFresh('foods_cache', const Duration(minutes: 5))) {
      final cached = getCachedFoods();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    }

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
      final rawBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(rawBody);
      if (data is! List) {
        throw const ApiException('Dữ liệu thực đơn không hợp lệ.');
      }

      // Save to cache for next sessions
      await LocalCacheService.save('foods_cache', rawBody);

      return data
          .whereType<Map<String, dynamic>>()
          .map(FoodItem.fromJson)
          .toList();
    } on ApiException {
      // Fallback to cache if network fails
      final fallback = getCachedFoods();
      if (fallback != null && fallback.isNotEmpty) return fallback;
      rethrow;
    } catch (_) {
      final fallback = getCachedFoods();
      if (fallback != null && fallback.isNotEmpty) return fallback;
      throw const ApiException('Không kết nối được máy chủ để tải thực đơn.');
    }
  }

  Future<List<FlashSaleCampaign>> fetchFlashSales({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        LocalCacheService.isFresh(
          'flash_sales_cache',
          const Duration(minutes: 2),
        )) {
      final cached = getCachedFlashSales();
      if (cached != null) return cached;
    }

    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/flash-sales/active'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return getCachedFlashSales() ?? const [];
      }
      final rawBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(rawBody);
      if (data is! List) return getCachedFlashSales() ?? const [];

      await LocalCacheService.save('flash_sales_cache', rawBody);

      return data
          .whereType<Map<String, dynamic>>()
          .map(FlashSaleCampaign.fromJson)
          .toList();
    } catch (_) {
      return getCachedFlashSales() ?? const [];
    }
  }

  Future<List<ComboItem>> fetchCombos({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        LocalCacheService.isFresh(
          'combos_cache',
          const Duration(minutes: 10),
        )) {
      final cached = getCachedCombos();
      if (cached != null) return cached;
    }

    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/foods/combos'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return getCachedCombos() ?? const [];
      }
      final rawBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(rawBody);
      if (data is! List) return getCachedCombos() ?? const [];

      await LocalCacheService.save('combos_cache', rawBody);

      return data
          .whereType<Map<String, dynamic>>()
          .map(ComboItem.fromJson)
          .toList();
    } catch (_) {
      return getCachedCombos() ?? const [];
    }
  }

  Future<List<FoodReviewItem>> fetchReviews({
    int? foodId,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final isHomeReviews = foodId == null;
    if (isHomeReviews &&
        !forceRefresh &&
        LocalCacheService.isFresh(
          'reviews_cache',
          const Duration(minutes: 5),
        )) {
      final cached = getCachedReviews();
      if (cached != null) return cached;
    }

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
        return isHomeReviews ? (getCachedReviews() ?? const []) : const [];
      }
      final rawBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(rawBody);
      List rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map && data['reviews'] is List) {
        rawList = data['reviews'] as List;
      } else if (data is Map && data['data'] is List) {
        rawList = data['data'] as List;
      } else {
        return isHomeReviews ? (getCachedReviews() ?? const []) : const [];
      }

      if (isHomeReviews) {
        await LocalCacheService.save('reviews_cache', rawBody);
      }

      return rawList
          .whereType<Map<String, dynamic>>()
          .map(FoodReviewItem.fromJson)
          .toList();
    } catch (_) {
      return isHomeReviews ? (getCachedReviews() ?? const []) : const [];
    }
  }

  Future<List<FoodCategory>> fetchCategories({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        LocalCacheService.isFresh(
          'categories_cache',
          const Duration(minutes: 15),
        )) {
      final cached = getCachedCategories();
      if (cached != null) return cached;
    }

    return _fetchList(
      '/foods/categories',
      'categories_cache',
      FoodCategory.fromJson,
      timeout: const Duration(seconds: 20),
    );
  }

  Future<List<HomeAnnouncement>> fetchAnnouncements(
    String token, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        LocalCacheService.isFresh(
          'announcements_cache',
          const Duration(minutes: 3),
        )) {
      final cached = getCachedAnnouncements();
      if (cached != null) return cached;
    }

    return _fetchList(
      '/announcements/archive',
      'announcements_cache',
      HomeAnnouncement.fromJson,
      token: token,
      timeout: const Duration(seconds: 20),
    );
  }

  Future<List<HomeAdvertisement>> fetchAdvertisements({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        LocalCacheService.isFresh(
          'advertisements_cache',
          const Duration(minutes: 10),
        )) {
      final cached = getCachedAdvertisements();
      if (cached != null) return cached;
    }

    return _fetchList(
      '/advertisements?limit=20',
      'advertisements_cache',
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
    String cacheKey,
    T Function(Map<String, dynamic>) fromJson, {
    String? token,
    required Duration timeout,
  }) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers(token))
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _readListFromCache(cacheKey, fromJson);
      }
      final rawBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(rawBody);
      if (data is! List) return _readListFromCache(cacheKey, fromJson);

      await LocalCacheService.save(cacheKey, rawBody);
      return data.whereType<Map<String, dynamic>>().map(fromJson).toList();
    } catch (_) {
      return _readListFromCache(cacheKey, fromJson);
    }
  }

  List<T> _readListFromCache<T>(
    String cacheKey,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = LocalCacheService.read(cacheKey);
    if (raw == null) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return data.whereType<Map<String, dynamic>>().map(fromJson).toList();
    } catch (_) {
      return const [];
    }
  }
}
