import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Ergebnis eines API-Calls – enthält Daten, Timestamp und Offline-Flag.
class CachedResult<T> {
  final T data;
  final DateTime? cachedAt;
  final bool isOffline;

  const CachedResult({
    required this.data,
    this.cachedAt,
    this.isOffline = false,
  });
}

/// Schreibt und liest API-Antworten aus dem lokalen Gerätespeicher.
/// Nutzt shared_preferences (key-value, persistent über App-Neustarts).
class CacheService {
  static const String _timestampSuffix = '__ts';

  /// Speichert [data] unter [key] mit aktuellem Timestamp.
  static Future<void> write(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(data);
    final timestamp = DateTime.now().toIso8601String();
    await prefs.setString(key, encoded);
    await prefs.setString('$key$_timestampSuffix', timestamp);
  }

  /// Liest gecachte Daten für [key].
  /// Gibt null zurück wenn kein Cache vorhanden.
  static Future<CachedResult<T>?> read<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    final tsRaw = prefs.getString('$key$_timestampSuffix');

    if (raw == null) return null;

    final data = jsonDecode(raw) as T;
    final cachedAt = tsRaw != null ? DateTime.tryParse(tsRaw) : null;

    return CachedResult<T>(
      data: data,
      cachedAt: cachedAt,
      isOffline: true,
    );
  }

  /// Löscht Cache-Eintrag für [key].
  static Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove('$key$_timestampSuffix');
  }

  /// Löscht den gesamten Kestrel-Cache.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}