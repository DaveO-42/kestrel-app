import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(Uri.parse('$baseUrl/dashboard'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Dashboard konnte nicht geladen werden');
  }

  static Future<List<dynamic>> getPositions() async {
    final response = await http.get(Uri.parse('$baseUrl/positions'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Positionen konnten nicht geladen werden');
  }

  static Future<Map<String, dynamic>> getPosition(String ticker) async {
    final response = await http.get(Uri.parse('$baseUrl/positions/$ticker'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Position $ticker nicht gefunden');
  }

  static Future<Map<String, dynamic>> getShortlist() async {
    final response = await http.get(Uri.parse('$baseUrl/shortlist'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Shortlist konnte nicht geladen werden');
  }

  static Future<Map<String, dynamic>> getHistory() async {
    final response = await http.get(Uri.parse('$baseUrl/history'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('History konnte nicht geladen werden');
  }

  static Future<Map<String, dynamic>> getHistorySummary() async {
    final response = await http.get(Uri.parse('$baseUrl/history/summary'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Summary konnte nicht geladen werden');
  }

  static Future<Map<String, dynamic>> getSystemStatus() async {
    final response = await http.get(Uri.parse('$baseUrl/system/status'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Systemstatus konnte nicht geladen werden');
  }

  static Future<List<dynamic>> getRuns({int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/runs?limit=$limit'),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Runs konnten nicht geladen werden');
  }
}