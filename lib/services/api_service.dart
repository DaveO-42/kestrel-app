import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ── Mock-Flag ─────────────────────────────────────────────────
  // true  → Daten aus assets/mock/*.json (kein Server nötig)
  // false → Echter Server (Pi oder lokaler Mock)
  static const bool useMock = true;

  static const String baseUrl = 'http://10.0.2.2:8000';

  // ── Interner Helper ───────────────────────────────────────────

  static Future<dynamic> _loadAsset(String path) async {
    final str = await rootBundle.loadString(path);
    return jsonDecode(str);
  }

  static Future<Map<String, dynamic>> _getMap(
      String mockPath, String endpoint) async {
    if (useMock) return await _loadAsset(mockPath) as Map<String, dynamic>;
    final response = await http.get(Uri.parse('$baseUrl$endpoint'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Fehler beim Laden von $endpoint');
  }

  static Future<List<dynamic>> _getList(
      String mockPath, String endpoint) async {
    if (useMock) return await _loadAsset(mockPath) as List<dynamic>;
    final response = await http.get(Uri.parse('$baseUrl$endpoint'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Fehler beim Laden von $endpoint');
  }

  // ── Endpoints ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDashboard() =>
      _getMap('assets/mock/dashboard.json', '/dashboard');

  static Future<List<dynamic>> getPositions() =>
      _getList('assets/mock/dashboard.json', '/positions');

  static Future<Map<String, dynamic>> getPosition(String ticker) async {
    if (useMock) {
      // Im Mock-Modus immer NVDA-Daten zurückgeben,
      // ticker wird ins JSON geschrieben damit der Screen den richtigen Ticker zeigt
      final data = await _loadAsset('assets/mock/position_nvda.json')
          as Map<String, dynamic>;
      return {...data, 'ticker': ticker};
    }
    final response =
        await http.get(Uri.parse('$baseUrl/positions/$ticker'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Position $ticker nicht gefunden');
  }

  static Future<Map<String, dynamic>> getShortlist() =>
      _getMap('assets/mock/shortlist.json', '/shortlist');

  static Future<Map<String, dynamic>> getHistory() =>
      _getMap('assets/mock/history.json', '/history');

  static Future<Map<String, dynamic>> getHistorySummary() =>
      _getMap('assets/mock/history_summary.json', '/history/summary');

  static Future<Map<String, dynamic>> getSystemStatus() =>
      _getMap('assets/mock/system_status.json', '/system/status');

  static Future<List<dynamic>> getRuns({int limit = 20}) async {
    if (useMock) {
      final list = await _loadAsset('assets/mock/runs.json') as List<dynamic>;
      return list.take(limit).toList();
    }
    final response =
        await http.get(Uri.parse('$baseUrl/runs?limit=$limit'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Runs konnten nicht geladen werden');
  }
}
