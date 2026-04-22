import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AuthService {
  static const _storage   = FlutterSecureStorage();
  static const _keyAccess  = 'access_token';
  static const _keyRefresh = 'refresh_token';

  Future<bool> login(String password) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _storage.write(key: _keyAccess,  value: data['access_token']  as String);
      await _storage.write(key: _keyRefresh, value: data['refresh_token'] as String? ?? '');
      return true;
    }
    if (response.statusCode == 401) return false;
    throw Exception('Login fehlgeschlagen: ${response.statusCode}');
  }

  Future<void> logout() async {
    await _storage.delete(key: _keyAccess);
    await _storage.delete(key: _keyRefresh);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: _keyAccess);
  }

  Future<String?> refreshToken() async {
    try {
      final refresh = await _storage.read(key: _keyRefresh);
      if (refresh == null || refresh.isEmpty) return null;
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refresh}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data     = jsonDecode(response.body) as Map<String, dynamic>;
        final newToken = data['access_token'] as String;
        await _storage.write(key: _keyAccess, value: newToken);
        return newToken;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _keyAccess);
    return token != null && token.isNotEmpty;
  }
}
