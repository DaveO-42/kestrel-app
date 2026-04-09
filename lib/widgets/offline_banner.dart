import 'package:flutter/material.dart';

/// Schmaler roter Banner direkt unter der AppBar.
/// Für History, Shortlist, System, Position Detail.
///
/// Verwendung in Screens:
///   if (_result?.isOffline == true)
///     OfflineBanner(cachedAt: _result!.cachedAt)
class OfflineBanner extends StatelessWidget {
  final DateTime? cachedAt;

  const OfflineBanner({super.key, this.cachedAt});

  String _formatAge() {
    if (cachedAt == null) return 'unbekannt';
    final d = DateTime.now().difference(cachedAt!);
    if (d.inMinutes < 1)  return 'wenigen Sekunden';
    if (d.inMinutes < 60) return '${d.inMinutes} Min.';
    if (d.inHours < 24)   return '${d.inHours} Std.';
    return '${d.inDays} Tag${d.inDays > 1 ? 'en' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1e0808),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFe84040),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Keine Verbindung · Daten von vor ${_formatAge()}',
              style: const TextStyle(
                color: Color(0xFFe84040),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}