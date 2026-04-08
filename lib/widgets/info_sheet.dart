import 'package:flutter/material.dart';
import '../theme/kestrel_theme.dart';

Future<void> showKestrelInfoSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xBF060A10),
    builder: (_) => const _InfoSheet(),
  );
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1623),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: Color(0xFF1E2E42))),
          ),
          child: Column(
            children: [
              // Drag Handle
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: 28,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2E42),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Logo zentriert, ✕ ganz rechts
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Platzhalter links für Symmetrie
                    const SizedBox(width: 48),
                    // Zentrierter Inhalt
                    Expanded(
                      child: Column(
                        children: [
                          KestrelLogo(size: 44),
                          const SizedBox(height: 6),
                          const Text(
                            'KESTREL',
                            style: TextStyle(
                              color: KestrelColors.goldLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Hover. Strike. Ride.',
                            style: TextStyle(
                              color: Color(0xFF8A6E2A),
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ✕ Button ganz rechts
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF141F2E),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF1E2E42)),
                          ),
                          child: const Center(
                            child: Text(
                              '✕',
                              style: TextStyle(
                                color: KestrelColors.textDimmed,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFF141F2E)),

              // Scrollbarer Inhalt
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 32),
                  children: const [
                    _SectionTitle('Screening Gates'),
                    _GateRow('G1', 'Earnings Beat', 'EPS-Überraschung ≤ 30 Tage'),
                    _GateRow('G2', 'Momentum', '4W Performance > 3 %'),
                    _GateRow('G3', 'Budget', 'Verfügbares Budget ≥ Mindestposition'),
                    _GateRow('G4', 'Preis', 'Kurs ≤ verfügbares Budget'),
                    _GateRow('G5', 'RSI', 'RSI 50–70 (Daily)'),
                    _GateRow('G6', 'Trend', 'Kurs > EMA20 > EMA50, Steigung positiv'),
                    _GateRow('G7', 'Earnings-Abstand', 'Nächste Earnings > 7 Tage'),
                    _GateRow('G8', 'SEC EDGAR', 'Kein K.O.-Kriterium im Filing'),
                    _SectionTitle('Score-Berechnung'),
                    _ScoreRow('EPS Surprise (Stärke des Katalysators)', '70 %'),
                    _ScoreRow('Performance 4W (Marktreaktion seit Beat)', '30 %'),
                    _ScoreNote(
                        'Höherer Score = stärkeres Signal. Tie-Breaking bei gleichen Kandidaten.'),
                    _SectionTitle('Signal-Hierarchie'),
                    _SignalRow('HARD', 'Sofortiger Handlungsbedarf',
                        'Stop auf ATR×1.0 gesetzt'),
                    _SignalRow('WARN', 'Trendumkehr erkannt',
                        'EMA20, RSI-Delta, Buchverlust'),
                    _SignalRow('INFO', 'Hinweis ohne Eingriff',
                        'Earnings-Nähe, Steigung negativ'),
                    _SectionTitle('Stop-Modi'),
                    _StopRow('Normal', 'ATR × 2.0'),
                    _StopRow('WARN aktiv', 'ATR × 1.0'),
                    _SectionTitle('Drawdown-Regeln'),
                    _RuleRow('Pause bei ≥ 25 % realisiertem Verlust'),
                    _RuleRow('Warnung bei 6 Verlusten in Folge'),
                    _RuleRow('Resume nur manuell via Telegram: /resume'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Section Title ─────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: KestrelColors.gold,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ── Gate Row ──────────────────────────────────────────────────

class _GateRow extends StatelessWidget {
  final String badge;
  final String name;
  final String sub;
  const _GateRow(this.badge, this.name, this.sub);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF111A26))),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: KestrelColors.screenBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: KestrelColors.gold),
            ),
            child: Center(
              child: Text(
                badge,
                style: const TextStyle(
                  color: KestrelColors.gold,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Color(0xFFDDE4F0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(sub,
                    style: const TextStyle(
                        color: Color(0xFF4A6080), fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Score Row ─────────────────────────────────────────────────

class _ScoreRow extends StatelessWidget {
  final String label;
  final String value;
  const _ScoreRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF111A26))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF8A9AB0), fontSize: 11)),
          ),
          Text(value,
              style: const TextStyle(
                color: Color(0xFFDDE4F0),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              )),
        ],
      ),
    );
  }
}

class _ScoreNote extends StatelessWidget {
  final String text;
  const _ScoreNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Text(text,
          style: const TextStyle(
              color: Color(0xFF4A6080), fontSize: 9, height: 1.4)),
    );
  }
}

// ── Signal Row ────────────────────────────────────────────────

class _SignalRow extends StatelessWidget {
  final String severity;
  final String name;
  final String sub;
  const _SignalRow(this.severity, this.name, this.sub);

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    final Color badgeBg;
    final Color badgeBorder;

    switch (severity) {
      case 'HARD':
        badgeColor = KestrelColors.red;
        badgeBg = const Color(0xFF1A0505);
        badgeBorder = const Color(0xFF4A1010);
        break;
      case 'WARN':
        badgeColor = KestrelColors.orange;
        badgeBg = const Color(0xFF1A1005);
        badgeBorder = const Color(0xFF4A2E08);
        break;
      default:
        badgeColor = const Color(0xFF78B0E8);
        badgeBg = const Color(0xFF05101A);
        badgeBorder = const Color(0xFF0A2A48);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF111A26))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: badgeBorder),
            ),
            child: Text(
              severity,
              style: TextStyle(
                color: badgeColor,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Color(0xFFDDE4F0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(sub,
                    style: const TextStyle(
                        color: Color(0xFF4A6080), fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stop Row ──────────────────────────────────────────────────

class _StopRow extends StatelessWidget {
  final String label;
  final String value;
  const _StopRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF111A26))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF8A9AB0), fontSize: 11)),
          Text(value,
              style: const TextStyle(
                color: Color(0xFFDDE4F0),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              )),
        ],
      ),
    );
  }
}

// ── Rule Row ──────────────────────────────────────────────────

class _RuleRow extends StatelessWidget {
  final String text;
  const _RuleRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF111A26))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: KestrelColors.gold,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFF8A9AB0),
                    fontSize: 11,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}