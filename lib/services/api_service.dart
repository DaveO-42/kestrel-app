import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'cache_service.dart';

class ApiService {
  // ── Mock-Flag ─────────────────────────────────────────────────
  static const bool useMock = false;
  static const String baseUrl = 'http://100.103.235.113:8000';
  static const _timeout = Duration(seconds: 8);

  // ── Cache-Keys ────────────────────────────────────────────────
  static const String _keyDashboard      = 'cache_dashboard';
  static const String _keyPositions      = 'cache_positions';
  static const String _keyShortlist      = 'cache_shortlist';
  static const String _keyHistory        = 'cache_history';
  static const String _keyHistorySummary = 'cache_history_summary';
  static const String _keySystemStatus   = 'cache_system_status';
  static const String _keyRuns           = 'cache_runs';

  static String _positionKey(String ticker) => 'cache_position_$ticker';

  // ── Interner Helper ───────────────────────────────────────────

  static Future<dynamic> _loadAsset(String path) async {
    final str = await rootBundle.loadString(path);
    return jsonDecode(str);
  }

  static Future<CachedResult<T>> getMapCached<T>(
      String mockPath, String endpoint, String cacheKey) async {
    if (useMock) {
      final data = await _loadAsset(mockPath);
      return CachedResult(data: data as T);
    }
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as T;
        await CacheService.write(cacheKey, data);
        return CachedResult(data: data, isOffline: false);
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (_) {
      final cached = await CacheService.read<T>(cacheKey);
      if (cached != null) return cached;
      rethrow;
    }
  }

  static Future<CachedResult<T>> getListCached<T>(
      String mockPath, String endpoint, String cacheKey) async {
    if (useMock) {
      final data = await _loadAsset(mockPath);
      return CachedResult(data: data as T);
    }
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as T;
        await CacheService.write(cacheKey, data);
        return CachedResult(data: data, isOffline: false);
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (_) {
      final cached = await CacheService.read<T>(cacheKey);
      if (cached != null) return cached;
      rethrow;
    }
  }

  // ── GET Endpoints ─────────────────────────────────────────────

  static Future<CachedResult<Map<String, dynamic>>> getDashboard() =>
      getMapCached('assets/mock/dashboard.json', '/dashboard', _keyDashboard);

  static Future<CachedResult<List<dynamic>>> getPositions() =>
      getListCached('assets/mock/dashboard.json', '/positions', _keyPositions);

  static Future<CachedResult<Map<String, dynamic>>> getPosition(
      String ticker) async {
    if (useMock) {
      final data = await _loadAsset('assets/mock/position_nvda.json')
      as Map<String, dynamic>;
      return CachedResult(data: {...data, 'ticker': ticker});
    }
    final key = _positionKey(ticker);
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/positions/$ticker'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await CacheService.write(key, data);
        return CachedResult(data: data, isOffline: false);
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (_) {
      final cached = await CacheService.read<Map<String, dynamic>>(key);
      if (cached != null) return cached;
      throw Exception('Position $ticker nicht gefunden');
    }
  }

  static Future<CachedResult<Map<String, dynamic>>> getShortlist() =>
      getMapCached('assets/mock/shortlist.json', '/shortlist', _keyShortlist);

  static Future<CachedResult<Map<String, dynamic>>> getHistory() =>
      getMapCached('assets/mock/history.json', '/history', _keyHistory);

  static Future<CachedResult<Map<String, dynamic>>> getHistorySummary() =>
      getMapCached('assets/mock/history_summary.json', '/history/summary',
          _keyHistorySummary);

  static Future<CachedResult<Map<String, dynamic>>> getSystemStatus() =>
      getMapCached('assets/mock/system_status.json', '/system/status',
          _keySystemStatus);

  static Future<CachedResult<List<dynamic>>> getRuns({int limit = 10}) =>
      getListCached('assets/mock/runs.json', '/runs?limit=$limit', _keyRuns);

  // ── Version ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getVersion() async {
    if (useMock) return {'backend': '0.0.0-mock', 'api': '1.0.0'};
    final response = await http
        .get(Uri.parse('$baseUrl/version'))
        .timeout(const Duration(seconds: 5));
    print('[version] status=${response.statusCode} body=${response.body}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  // ── Verbindungstest ───────────────────────────────────────────

  static Future<int> testConnection() async {
    final stopwatch = Stopwatch()..start();
    final response = await http
        .get(Uri.parse('$baseUrl/health'))
        .timeout(const Duration(seconds: 5));
    stopwatch.stop();
    if (response.statusCode == 200) return stopwatch.elapsedMilliseconds;
    throw Exception('Server antwortete mit ${response.statusCode}');
  }

  // ── POST Action Endpoints ─────────────────────────────────────

  static Future<Map<String, dynamic>> postBought({
    required String ticker,
    required int quantity,
    required double fillPriceEur,
    required double stopEur,
    required double atrEur,
    String notes = '',
  }) async {
    final body = jsonEncode({
      'ticker': ticker,
      'quantity': quantity,
      'fill_price_eur': fillPriceEur,
      'stop_eur': stopEur,
      'atr_eur': atrEur,
      'notes': notes,
    });
    return _postAction('/actions/bought', body);
  }

  static Future<Map<String, dynamic>> postSold({
    required String ticker,
    required double fillPriceEur,
  }) async {
    final body = jsonEncode({
      'ticker': ticker,
      'fill_price_eur': fillPriceEur,
    });
    return _postAction('/actions/sold', body);
  }

  static Future<Map<String, dynamic>> postSkip(String ticker) async {
    final body = jsonEncode({'ticker': ticker});
    return _postAction('/actions/skip', body);
  }

  static Future<Map<String, dynamic>> postResume() async {
    return _postAction('/actions/resume', '{}');
  }

  static Future<Map<String, dynamic>> _postAction(
      String endpoint, String body) async {
    // Im Mock-Modus: sofort Erfolg zurückgeben ohne Netzwerkzugriff
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 400)); // realistisches Feedback
      return {'ok': true};
    }
    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      )
          .timeout(_timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) return data;

      final detail = data['detail'] as String? ?? 'Unbekannter Fehler';
      throw ActionException(detail, statusCode: response.statusCode);
    } on ActionException {
      rethrow;
    } catch (e) {
      throw ActionException('Verbindungsfehler: $e');
    }
  }
}

// ── ActionException ───────────────────────────────────────────

class ActionException implements Exception {
  final String message;
  final int? statusCode;
  const ActionException(this.message, {this.statusCode});

  @override
  String toString() => message;
}