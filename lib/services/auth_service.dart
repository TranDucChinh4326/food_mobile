import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/api_config.dart';
import '../models/auth_session.dart';
import 'api_exception.dart';

class AuthService {
  AuthService({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'bep1979_access_token';
  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<AuthSession> login({required String login, required String password}) {
    return _authenticate('/auth/login', {
      'login': login.trim(),
      'password': password,
    });
  }

  Future<AuthSession> register({
    required String fullname,
    required String username,
    required String email,
    required String password,
  }) {
    return _authenticate('/auth/register', {
      'fullname': fullname.trim(),
      'username': username.trim().toLowerCase(),
      'email': email.trim().toLowerCase(),
      'password': password,
    });
  }

  Future<Map<String, dynamic>> loginWithGoogle(String accessToken) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/google'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'accessToken': accessToken}),
    );
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['message']?.toString() ?? 'Đăng nhập Google thất bại.',
        statusCode: response.statusCode,
      );
    }
    if (data['requiresAccountSetup'] == true) {
      return data;
    }
    final token = data['token']?.toString() ?? '';
    final userData = data['user'];
    if (token.isNotEmpty && userData is Map<String, dynamic>) {
      await _storage.write(key: _tokenKey, value: token);
      return {
        'session': AuthSession(token: token, user: AuthUser.fromJson(userData)),
      };
    }
    throw const ApiException('Phản hồi Google không hợp lệ.');
  }

  Future<AuthSession> completeSocialSetup({
    required String provider,
    required String accessToken,
    required String username,
    required String fullname,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/social/setup/$provider'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'accessToken': accessToken,
        'username': username.trim().toLowerCase(),
        'fullname': fullname.trim(),
        'password': password,
      }),
    );
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['message']?.toString() ?? 'Hoàn tất tài khoản thất bại.',
        statusCode: response.statusCode,
      );
    }
    final token = data['token']?.toString() ?? '';
    final userData = data['user'];
    if (token.isEmpty || userData is! Map<String, dynamic>) {
      throw const ApiException('Phản hồi hoàn tất tài khoản không hợp lệ.');
    }
    await _storage.write(key: _tokenKey, value: token);
    return AuthSession(token: token, user: AuthUser.fromJson(userData));
  }

  Future<AuthSession?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      final data = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await logout();
        return null;
      }
      final userJson = data['user'] is Map<String, dynamic>
          ? data['user'] as Map<String, dynamic>
          : data;
      return AuthSession(token: token, user: AuthUser.fromJson(userJson));
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() => _storage.delete(key: _tokenKey);

  // ==========================================
  // PROFILE & ACCOUNT APIs
  // ==========================================

  Future<AuthUser> fetchProfile(String token) async {
    final data = await _get('/auth/me', token);
    final userJson = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    return AuthUser.fromJson(userJson);
  }

  Future<AuthUser> updateProfile(
    String token, {
    required String username,
    required String fullname,
    required String email,
    required String phone,
    String? address,
    String? avatar,
  }) async {
    final payload = <String, dynamic>{
      'username': username.trim().toLowerCase(),
      'fullname': fullname.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
    };
    if (address != null) payload['address'] = address.trim();
    if (avatar != null) payload['avatar'] = avatar.trim();

    final data = await _put('/auth/me', token, payload);
    final userJson = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    return AuthUser.fromJson(userJson);
  }

  Future<AuthUser> updatePresetAvatar(String token, String presetAvatar) async {
    final data = await _post('/auth/avatar', token, {
      'presetAvatar': presetAvatar.trim(),
    });
    final userJson = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    return AuthUser.fromJson(userJson);
  }

  Future<AuthUser> uploadAvatarBytes(
    String token,
    List<int> bytes,
    String filename,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/avatar');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    // Detect MIME type from file extension so multer on the backend
    // correctly identifies this as an image (its fileFilter checks mimetype).
    final ext = filename.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/jpeg', // iOS HEIC → treat as jpeg
      _ => 'image/jpeg', // safe fallback
    };

    request.files.add(
      http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: filename,
        contentType: MediaType.parse(mime),
      ),
    );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['message']?.toString() ?? 'Tải ảnh đại diện thất bại.',
        statusCode: response.statusCode,
      );
    }
    final userJson = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    return AuthUser.fromJson(userJson);
  }

  // ==========================================
  // ADDRESS BOOK APIs
  // ==========================================

  Future<List<UserAddress>> fetchAddresses(String token) async {
    final data = await _get('/auth/addresses', token);
    final rawList = data['addresses'] as List<dynamic>? ?? [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(UserAddress.fromJson)
        .toList();
  }

  Future<void> createAddress(
    String token, {
    required String label,
    required String receiverName,
    required String phone,
    required String address,
    required bool isDefault,
  }) async {
    await _post('/auth/addresses', token, {
      'label': label.trim(),
      'receiverName': receiverName.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'isDefault': isDefault,
    });
  }

  Future<void> updateAddress(
    String token,
    int id, {
    required String label,
    required String receiverName,
    required String phone,
    required String address,
    required bool isDefault,
  }) async {
    await _put('/auth/addresses/$id', token, {
      'label': label.trim(),
      'receiverName': receiverName.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'isDefault': isDefault,
    });
  }

  Future<void> deleteAddress(String token, int id) async {
    await _delete('/auth/addresses/$id', token);
  }

  // ==========================================
  // VOUCHER APIs
  // ==========================================

  Future<List<UserVoucher>> fetchVouchers(String token) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/orders/vouchers/mine'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(UserVoucher.fromJson)
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  // ==========================================
  // FAVORITE FOODS APIs
  // ==========================================

  Future<List<FavoriteFoodItem>> fetchFavoriteFoods(String token) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/foods/favorites/detail'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(FavoriteFoodItem.fromJson)
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> removeFavoriteFood(String token, int foodId) async {
    await _delete('/foods/favorites/$foodId', token);
  }

  // ==========================================
  // PASSWORD & CAPTCHA APIs
  // ==========================================

  Future<PasswordCaptcha> fetchPasswordCaptcha(String token) async {
    final data = await _get('/auth/password-captcha', token);
    return PasswordCaptcha.fromJson(data);
  }

  Future<String> changePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
    required String captchaAnswer,
    required String captchaId,
  }) async {
    final data = await _put('/auth/password', token, {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
      'captchaAnswer': captchaAnswer.trim().toLowerCase(),
      'captchaId': captchaId,
    });
    return data['message']?.toString() ?? 'Đổi mật khẩu thành công.';
  }

  // ==========================================
  // PIN APIs
  // ==========================================

  Future<AuthUser> savePin(
    String token, {
    String? currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    final payload = <String, dynamic>{
      'newPin': newPin.trim(),
      'confirmPin': confirmPin.trim(),
    };
    if (currentPin != null && currentPin.isNotEmpty) {
      payload['currentPin'] = currentPin.trim();
    }
    final data = await _put('/auth/pin', token, payload);
    final userJson = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    return AuthUser.fromJson(userJson);
  }

  // ==========================================
  // SOCIAL ACCOUNTS API
  // ==========================================

  Future<List<SocialAccount>> fetchSocialAccounts(String token) async {
    try {
      final data = await _get('/auth/social/accounts', token);
      final rawList = data['accounts'] as List<dynamic>? ?? [];
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(SocialAccount.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ==========================================
  // QR WEB LOGIN APIs (Web generates QR -> App scans & confirms)
  // ==========================================

  Future<Map<String, dynamic>> scanQrSession(
    String token,
    String codeOrSessionId,
  ) async {
    return _post('/auth/qr/session/scan', token, {
      'sessionId': codeOrSessionId.trim(),
      'code': codeOrSessionId.trim(),
    });
  }

  Future<Map<String, dynamic>> scanQrImage(
    String token,
    List<int> imageBytes,
    String filename,
  ) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/qr/session/scan-image');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'application/json';

      final ext = filename.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
          contentType: MediaType.parse(mime),
        ),
      );

      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      final data = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          data['message']?.toString() ?? 'Không thể nhận diện mã QR từ ảnh.',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>> confirmQrSession(
    String token,
    String sessionId,
  ) async {
    return _post('/auth/qr/session/confirm', token, {
      'sessionId': sessionId.trim(),
      'code': sessionId.trim(),
    });
  }

  Future<Map<String, dynamic>> rejectQrSession(
    String token,
    String sessionId,
  ) async {
    return _post('/auth/qr/session/reject', token, {
      'sessionId': sessionId.trim(),
      'code': sessionId.trim(),
    });
  }

  // Legacy
  Future<Map<String, dynamic>> generateQrLogin(String token) async {
    return _post('/auth/qr/generate', token, {});
  }

  Future<Map<String, dynamic>> checkQrStatus(String token, String code) async {
    return _get('/auth/qr/status/$code', token);
  }

  // ==========================================
  // HTTP HELPERS
  // ==========================================

  Future<Map<String, dynamic>> _get(String path, String token) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 25));
      final data = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          data['message']?.toString() ?? 'Không thể xử lý yêu cầu.',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('Không thể kết nối máy chủ. Vui lòng thử lại.');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    String token,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
      final data = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          data['message']?.toString() ?? 'Không thể xử lý yêu cầu.',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('Không thể kết nối máy chủ. Vui lòng thử lại.');
    }
  }

  Future<Map<String, dynamic>> _put(
    String path,
    String token,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .put(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
      final data = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          data['message']?.toString() ?? 'Không thể xử lý yêu cầu.',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('Không thể kết nối máy chủ. Vui lòng thử lại.');
    }
  }

  Future<Map<String, dynamic>> _delete(String path, String token) async {
    try {
      final response = await _client
          .delete(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 25));
      final data = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          data['message']?.toString() ?? 'Không thể xử lý yêu cầu.',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException('Không thể kết nối máy chủ. Vui lòng thử lại.');
    }
  }

  Future<AuthSession> _authenticate(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      final data = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          data['message']?.toString() ?? 'Không thể xử lý yêu cầu.',
          statusCode: response.statusCode,
        );
      }

      final token = data['token']?.toString() ?? '';
      final userData = data['user'];
      if (token.isEmpty || userData is! Map<String, dynamic>) {
        throw const ApiException('Phản hồi đăng nhập không hợp lệ.');
      }
      await _storage.write(key: _tokenKey, value: token);
      return AuthSession(token: token, user: AuthUser.fromJson(userData));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Không kết nối được máy chủ. Vui lòng thử lại.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } catch (_) {
      return const {'message': 'Máy chủ trả về dữ liệu không hợp lệ.'};
    }
  }
}
