import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

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
