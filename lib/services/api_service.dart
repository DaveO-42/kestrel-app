import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'cache_service.dart';

class ApiService {
  // ── Mock-Flag ─────────────────────────────────────────────────
  static const bool useMock = bool.fromEnvironment(
      'USE_MOCK', defaultValue: false);
  static String baseUrl = 'https://api.kestrel-trading.com';
  static const _timeout = Duration(seconds: 8);

  static Future<void> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('server_url');
    if (saved != null && saved.isNotEmpty) baseUrl = saved;
  }

  // ── Cache-Keys ────────────────────────────────────────────────
  static const String _keyDashboard = 'cache_dashboard';
  static const String _keyPositions = 'cache_positions';
  static const String _keyShortlist = 'cache_shortlist';
  static const String _keyHistory = 'cache_history';
  static const String _keyHistorySummary   = 'cache_history_summary';
  static const String _keyHistoryBenchmark = 'cache_history_benchmark';
  static const String _keySandboxBaseline  = 'sandbox_baseline';
  static const String _keySystemStatus = 'cache_system_status';
  static const String _keyRuns = 'cache_runs';

  static String _positionKey(String ticker) => 'cache_position_$ticker';

  // ── Interner Helper ───────────────────────────────────────────

  static Future<dynamic> _loadAsset(String path) async {
    final str = await rootBundle.loadString(path);
    return jsonDecode(str);
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService().getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<CachedResult<T>> getMapCached<T>(String mockPath,
      String endpoint, String cacheKey) async {
    if (useMock) {
      final data = await _loadAsset(mockPath);
      return CachedResult(data: data as T);
    }
    try {
      final headers = await _authHeaders();
      var response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode == 401) {
        final newToken = await AuthService().refreshToken();
        if (newToken != null) {
          response = await http
              .get(Uri.parse('$baseUrl$endpoint'),
              headers: {...headers, 'Authorization': 'Bearer $newToken'})
              .timeout(_timeout);
        }
        if (response.statusCode == 401) {
          await AuthService().logout();
          onAuthError?.call();
          throw const ActionException('Sitzung abgelaufen.',
              statusCode: 401, isAuthError: true);
        }
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as T;
        await CacheService.write(cacheKey, data);
        return CachedResult(data: data, isOffline: false);
      }
      throw Exception('HTTP ${response.statusCode}');
    } on ActionException {
      rethrow;
    } catch (_) {
      final cached = await CacheService.read<T>(cacheKey);
      if (cached != null) return cached;
      rethrow;
    }
  }

  static Future<CachedResult<T>> getListCached<T>(String mockPath,
      String endpoint, String cacheKey) async {
    if (useMock) {
      final data = await _loadAsset(mockPath);
      return CachedResult(data: data as T);
    }
    try {
      final headers = await _authHeaders();
      var response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode == 401) {
        final newToken = await AuthService().refreshToken();
        if (newToken != null) {
          response = await http
              .get(Uri.parse('$baseUrl$endpoint'),
              headers: {...headers, 'Authorization': 'Bearer $newToken'})
              .timeout(_timeout);
        }
        if (response.statusCode == 401) {
          await AuthService().logout();
          onAuthError?.call();
          throw const ActionException('Sitzung abgelaufen.',
              statusCode: 401, isAuthError: true);
        }
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as T;
        await CacheService.write(cacheKey, data);
        return CachedResult(data: data, isOffline: false);
      }
      throw Exception('HTTP ${response.statusCode}');
    } on ActionException {
      rethrow;
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
      getListCached(
          'assets/mock/position_nvda.json', '/positions', _keyPositions);

  static Future<CachedResult<Map<String, dynamic>>> getPosition(
      String ticker) async {
    if (useMock) {
      final data = await _loadAsset('assets/mock/position_nvda.json')
      as Map<String, dynamic>;
      return CachedResult(data: {...data, 'ticker': ticker});
    }
    final key = _positionKey(ticker);
    try {
      final headers = await _authHeaders();
      var response = await http
          .get(Uri.parse('$baseUrl/positions/$ticker'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode == 401) {
        final newToken = await AuthService().refreshToken();
        if (newToken != null) {
          response = await http
              .get(Uri.parse('$baseUrl/positions/$ticker'),
              headers: {...headers, 'Authorization': 'Bearer $newToken'})
              .timeout(_timeout);
        }
        if (response.statusCode == 401) {
          await AuthService().logout();
          onAuthError?.call();
          throw const ActionException('Sitzung abgelaufen.',
              statusCode: 401, isAuthError: true);
        }
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await CacheService.write(key, data);
        return CachedResult(data: data, isOffline: false);
      }
      throw Exception('HTTP ${response.statusCode}');
    } on ActionException {
      rethrow;
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

  static Future<CachedResult<Map<String, dynamic>>> getHistoryBenchmark() =>
      getMapCached('assets/mock/history_benchmark.json', '/history/benchmark',
          _keyHistoryBenchmark);

  static Future<CachedResult<Map<String, dynamic>>> getSandboxBaseline() =>
      getMapCached('assets/mock/sandbox_baseline.json', '/sandbox/baseline',
          _keySandboxBaseline);

  static Future<CachedResult<Map<String, dynamic>>> getSystemStatus() =>
      getMapCached('assets/mock/system_status.json', '/system/status',
          _keySystemStatus);

  static Future<Map<String, dynamic>?> getSystemHealth() async {
    if (useMock) return null;
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/system/health'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<CachedResult<List<dynamic>>> getRuns({int limit = 10}) =>
      getListCached('assets/mock/runs.json', '/runs?limit=$limit', _keyRuns);

  // ── Version ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getVersion() async {
    if (useMock) return {'backend': '0.0.0-mock', 'api': '1.0.0'};
    try {
      final headers  = await _authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/version'), headers: headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ── Verbindungstest ───────────────────────────────────────────

  static Future<int> testConnection() async {
    try {
      final stopwatch = Stopwatch()
        ..start();
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      if (response.statusCode == 200) return stopwatch.elapsedMilliseconds;
      throw Exception('Server antwortete mit ${response.statusCode}');
    } catch (e, stack) {
      print('[kestrel] testConnection error: $e');
      print('[kestrel] stack: $stack');
      rethrow;
    }
  }

  // ── Candidate Chart ──────────────────────────────────────────

  static Future<Map<String, dynamic>> getPositionChart(String ticker) async {
    final headers = await _authHeaders();
    var response = await http
        .get(Uri.parse('$baseUrl/positions/$ticker/chart'), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      final newToken = await AuthService().refreshToken();
      if (newToken != null) {
        response = await http
            .get(Uri.parse('$baseUrl/positions/$ticker/chart'),
            headers: {...headers, 'Authorization': 'Bearer $newToken'})
            .timeout(const Duration(seconds: 15));
      }
      if (response.statusCode == 401) {
        await AuthService().logout();
        onAuthError?.call();
        throw const ActionException('Sitzung abgelaufen.',
            statusCode: 401, isAuthError: true);
      }
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Chart HTTP ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> getCandidateChart(String ticker) async {
    final headers = await _authHeaders();
    var response = await http
        .get(Uri.parse('$baseUrl/candidates/$ticker/chart'), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      final newToken = await AuthService().refreshToken();
      if (newToken != null) {
        response = await http
            .get(Uri.parse('$baseUrl/candidates/$ticker/chart'),
            headers: {...headers, 'Authorization': 'Bearer $newToken'})
            .timeout(const Duration(seconds: 15));
      }
      if (response.statusCode == 401) {
        await AuthService().logout();
        onAuthError?.call();
        throw const ActionException('Sitzung abgelaufen.',
            statusCode: 401, isAuthError: true);
      }
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Chart HTTP ${response.statusCode}');
  }

  // ── FCM Token ────────────────────────────────────────────────

  static Future<void> postFcmToken(String token) async {
    try {
      await _postAction('/system/fcm-token', jsonEncode({'token': token}));
    } catch (e) {
      debugPrint('FCM token upload failed: $e');
    }
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

  static Future<Map<String, dynamic>> postShutdown() async {
    return _postAction('/system/shutdown', '{}');
  }

  static Future<Map<String, dynamic>> triggerRun() async {
    return _postAction('/actions/trigger-run', '{}');
  }

  static VoidCallback? onAuthError;

  static Future<Map<String, dynamic>> _postAction(String endpoint,
      String body) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return {'ok': true};
    }
    try {
      final token = await AuthService().getAccessToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      var response = await http
          .post(Uri.parse('$baseUrl$endpoint'), headers: headers, body: body)
          .timeout(_timeout);

      if (response.statusCode == 401) {
        final newToken = await AuthService().refreshToken();
        if (newToken != null) {
          response = await http
              .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {...headers, 'Authorization': 'Bearer $newToken'},
            body: body,
          )
              .timeout(_timeout);
        }
        if (response.statusCode == 401) {
          await AuthService().logout();
          onAuthError?.call();
          throw const ActionException('Sitzung abgelaufen.',
              statusCode: 401, isAuthError: true);
        }
      }

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

  // ── Sandbox ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> postSandboxRun({
    required double atrMultiplier,
    required int rsiMin,
    required int rsiMax,
    required double minPerfPct,
    required List<int> years,
  }) async {
    final body = jsonEncode({
      'atr_multiplier': atrMultiplier,
      'rsi_min': rsiMin,
      'rsi_max': rsiMax,
      'min_perf_pct': minPerfPct,
      'years': years,
      'universe': 'combined',
    });
    return _postAction('/sandbox/run', body);
  }

  static Future<Map<String, dynamic>> postSandboxCancel(String jobId) async {
    return _postAction('/sandbox/cancel/$jobId', '{}');
  }

  static Future<Map<String, dynamic>> getSandboxStatus(String jobId) async {
    if (useMock) return {
      'status': 'done',
      'message': 'Fertig',
      'current': 3,
      'total': 3,
      'result': null,
      'error': null
    };
    try {
      final headers = await _authHeaders();
      var response = await http
          .get(Uri.parse('$baseUrl/sandbox/status/$jobId'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode == 401) {
        final newToken = await AuthService().refreshToken();
        if (newToken != null) {
          response = await http
              .get(Uri.parse('$baseUrl/sandbox/status/$jobId'),
              headers: {...headers, 'Authorization': 'Bearer $newToken'})
              .timeout(_timeout);
        }
        if (response.statusCode == 401) {
          await AuthService().logout();
          onAuthError?.call();
          throw const ActionException(
              'Sitzung abgelaufen.', statusCode: 401, isAuthError: true);
        }
      }
      if (response.statusCode == 200)
        return jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception('HTTP ${response.statusCode}');
    } on ActionException {
      rethrow;
    } catch (e) {
      throw ActionException('Verbindungsfehler: $e');
    }
  }

// ── Paper Trading ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> getPaperSummary() async {
    if (useMock) return {'total_trades': 0, 'win_rate': null,
        'avg_return': null, 'sharpe': null, 'open_positions': 0};
    try {
      final headers = await _authHeaders();
      var response = await http
          .get(Uri.parse('$baseUrl/paper/summary'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode == 401) {
        final newToken = await AuthService().refreshToken();
        if (newToken != null) {
          response = await http
              .get(Uri.parse('$baseUrl/paper/summary'),
              headers: {...headers, 'Authorization': 'Bearer $newToken'})
              .timeout(_timeout);
        }
        if (response.statusCode == 401) {
          await AuthService().logout();
          onAuthError?.call();
          throw const ActionException('Sitzung abgelaufen.',
              statusCode: 401, isAuthError: true);
        }
      }
      if (response.statusCode == 200)
        return jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception('HTTP ${response.statusCode}');
    } on ActionException {
      rethrow;
    } catch (e) {
      throw ActionException('Verbindungsfehler: $e');
    }
  }

  static Future<List<dynamic>> getPaperPositions() async {
    if (useMock) return [];
    try {
      final headers = await _authHeaders();
      var response = await http
          .get(Uri.parse('$baseUrl/paper/positions'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode == 401) {
        final newToken = await AuthService().refreshToken();
        if (newToken != null) {
          response = await http
              .get(Uri.parse('$baseUrl/paper/positions'),
              headers: {...headers, 'Authorization': 'Bearer $newToken'})
              .timeout(_timeout);
        }
        if (response.statusCode == 401) {
          await AuthService().logout();
          onAuthError?.call();
          throw const ActionException('Sitzung abgelaufen.',
              statusCode: 401, isAuthError: true);
        }
      }
      if (response.statusCode == 200)
        return (jsonDecode(response.body) as Map<String, dynamic>)['positions'] as List<dynamic>;
      throw Exception('HTTP ${response.statusCode}');
    } on ActionException {
      rethrow;
    } catch (e) {
      throw ActionException('Verbindungsfehler: $e');
    }
  }

  static Future<List<dynamic>> getPaperHistory() async {
    if (useMock) return [];
    try {
      final headers = await _authHeaders();
      var response = await http
          .get(Uri.parse('$baseUrl/paper/history'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode == 401) {
        final newToken = await AuthService().refreshToken();
        if (newToken != null) {
          response = await http
              .get(Uri.parse('$baseUrl/paper/history'),
              headers: {...headers, 'Authorization': 'Bearer $newToken'})
              .timeout(_timeout);
        }
        if (response.statusCode == 401) {
          await AuthService().logout();
          onAuthError?.call();
          throw const ActionException('Sitzung abgelaufen.',
              statusCode: 401, isAuthError: true);
        }
      }
      if (response.statusCode == 200)
        return (jsonDecode(response.body) as Map<String, dynamic>)['history'] as List<dynamic>;
      throw Exception('HTTP ${response.statusCode}');
    } on ActionException {
      rethrow;
    } catch (e) {
      throw ActionException('Verbindungsfehler: $e');
    }
  }

// ── Kalender ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getCalendar(
      {String filter = 'all'}) async {
    if (useMock)
      return {'days': [], 'fetched_at': DateTime.now().toIso8601String()};
    try {
      final headers = await _authHeaders();
      var response = await http
          .get(
          Uri.parse('$baseUrl/lab/calendar?filter=$filter'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode == 401) {
        final newToken = await AuthService().refreshToken();
        if (newToken != null) {
          response = await http
              .get(Uri.parse('$baseUrl/lab/calendar?filter=$filter'),
              headers: {...headers, 'Authorization': 'Bearer $newToken'})
              .timeout(_timeout);
        }
        if (response.statusCode == 401) {
          await AuthService().logout();
          onAuthError?.call();
          throw const ActionException(
              'Sitzung abgelaufen.', statusCode: 401, isAuthError: true);
        }
      }
      if (response.statusCode == 200)
        return jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception('HTTP ${response.statusCode}');
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
  final bool isAuthError;
  const ActionException(this.message, {this.statusCode, this.isAuthError = false});

  @override
  String toString() => message;
}