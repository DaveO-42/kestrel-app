import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'cache_service.dart';

class ApiService {
  // ── Mock-Flag ─────────────────────────────────────────────────
  // true  → Daten aus assets/mock/*.json (kein Server nötig)
  // false → Echter Server (Pi oder lokaler Mock)
  static const bool useMock = false;

  static const String baseUrl = 'http://100.103.235.113:8000';

  static const _timeout = Duration(seconds: 8);

  // ── Cache-Keys ────────────────────────────────────────────────
  static const String _keyDashboard = 'cache_dashboard';
  static const String _keyPositions = 'cache_positions';
  static const String _keyShortlist = 'cache_shortlist';
  static const String _keyHistory = 'cache_history';
  static const String _keyHistorySummary = 'cache_history_summary';
  static const String _keySystemStatus = 'cache_system_status';
  static const String _keyRuns = 'cache_runs';

  static String _positionKey(String ticker) => 'cache_position_$ticker';

  // ── Interner Helper ───────────────────────────────────────────

  static Future<dynamic> _loadAsset(String path) async {
    final str = await rootBundle.loadString(path);
    return jsonDecode(str);
  }

  /// Führt GET-Request durch. Bei Erfolg: Cache schreiben.
  /// Bei Fehler: Cache lesen und isOffline=true setzen.
  /// Wirft Exception nur wenn auch kein Cache vorhanden.
  static Future<CachedResult<Map<String, dynamic>>> getMapCached(
      String mockPath,
      String endpoint,
      String cacheKey,
      ) async {
    if (useMock) {
      final data = await _loadAsset(mockPath) as Map<String, dynamic>;
      return CachedResult(data: data);
    }

    try {
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await CacheService.write(cacheKey, data);
        return CachedResult(data: data, isOffline: false);
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (_) {
      final cached = await CacheService.read<Map<String, dynamic>>(cacheKey);
      if (cached != null) return cached;
      rethrow;
    }
  }

  static Future<CachedResult<List<dynamic>>> getListCached(
      String mockPath,
      String endpoint,
      String cacheKey,
      ) async {
    if (useMock) {
      final data = await _loadAsset(mockPath) as List<dynamic>;
      return CachedResult(data: data);
    }

    try {
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        await CacheService.write(cacheKey, data);
        return CachedResult(data: data, isOffline: false);
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (_) {
      final cached = await CacheService.read<List<dynamic>>(cacheKey);
      if (cached != null) return cached;
      rethrow;
    }
  }

  // ── Endpoints ─────────────────────────────────────────────────

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
      getMapCached(
          'assets/mock/system_status.json', '/system/status', _keySystemStatus);

  static Future<CachedResult<List<dynamic>>> getRuns({int limit = 20}) async {
    if (useMock) {
      final list = await _loadAsset('assets/mock/runs.json') as List<dynamic>;
      return CachedResult(data: list.take(limit).toList());
    }

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/runs?limit=$limit'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = (jsonDecode(response.body) as List<dynamic>)
            .take(limit)
            .toList();
        await CacheService.write(_keyRuns, data);
        return CachedResult(data: data, isOffline: false);
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (_) {
      final cached = await CacheService.read<List<dynamic>>(_keyRuns);
      if (cached != null) {
        return CachedResult(
          data: cached.data.take(limit).toList(),
          cachedAt: cached.cachedAt,
          isOffline: true,
        );
      }
      throw Exception('Runs konnten nicht geladen werden');
    }
  }

  // ── Verbindungstest ───────────────────────────────────────────
  static Future<int> testConnection() async {
    final stopwatch = Stopwatch()..start();
    final response = await http
        .get(Uri.parse('$baseUrl/dashboard'))
        .timeout(const Duration(seconds: 5));
    stopwatch.stop();
    if (response.statusCode == 200) return stopwatch.elapsedMilliseconds;
    throw Exception('Server antwortete mit ${response.statusCode}');
  }
}