import 'package:flutter/material.dart';

// ── Kestrel Design-Tokens ─────────────────────────────────────
// Abgeleitet aus dem Kestrel-Logo (Falke + Goldpfeil auf Navy)
// Einzige Quelle der Wahrheit für alle Farben in der App.

class KestrelColors {
  KestrelColors._();

  // Hintergründe (3 Ebenen)
  static const screenBg   = Color(0xFF0F1822); // Ebene 1: App-Hintergrund
  static const cardBg     = Color(0xFF1B2A3E); // Ebene 2: Cards
  static const cardBorder = Color(0xFF2E4A6A); // Card-Kante
  static const innerBg    = Color(0xFF0F1822); // Ebene 3: Inner-Cells = screenBg
  static const appBarBg   = Color(0xFF131F2E); // AppBar / Nav / Price-Hero

  // Akzent: Gold
  static const gold      = Color(0xFFC9A84C); // Labels, Nav-aktiv, CTAs, Borders
  static const goldLight = Color(0xFFF0D080); // AppBar-Titel, Score-Pills

  // Text-Hierarchie
  static const textPrimary = Color(0xFFE8EEF8); // Zahlen, Ticker, Preise
  static const textGrey    = Color(0xFFC8D4E8); // Labels, Stats, Sublabels
  static const textDimmed  = Color(0xFF6A8AAA); // Sekundäre Info, Timestamps
  static const textHint    = Color(0xFF334D68); // Wirklich unwichtig

  // Semantische Farben (fest, nie für andere Bedeutungen verwenden)
  static const green  = Color(0xFF27C97A); // P&L positiv, Trend intakt
  static const red    = Color(0xFFE84040); // P&L negativ, Stop, HARD
  static const orange = Color(0xFFE07820); // WARN-Signale, Kurs im Minus

  // Abgeleitete Badge-Farben (Hintergrund / Border)
  static const greenBg     = Color(0xFF0A2016);
  static const greenBorder = Color(0xFF1A6040);
  static const redBg       = Color(0xFF200808);
  static const redBorder   = Color(0xFF702020);
  static const orangeBg    = Color(0xFF201208);
  static const orangeBorder= Color(0xFF704010);
  static const goldBg      = Color(0xFF1E1408);
  static const goldBorder  = Color(0xFF8A6E2A);
  static const infoBg      = Color(0xFF081828);
  static const infoBorder  = Color(0xFF285888);
  static const infoText    = Color(0xFF78B0E8);
  static const grayBg      = Color(0xFF0F1822);
  static const grayBorder  = Color(0xFF1B2A3E);
}

// ── Kestrel ThemeData ─────────────────────────────────────────

class KestrelTheme {
  KestrelTheme._();

  static ThemeData get theme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: KestrelColors.gold,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: KestrelColors.screenBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: KestrelColors.appBarBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: KestrelColors.goldLight,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
      iconTheme: IconThemeData(color: KestrelColors.textDimmed),
    ),
    cardTheme: CardThemeData(
      color: KestrelColors.cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: KestrelColors.cardBorder),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: KestrelColors.cardBorder,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: KestrelColors.gold,
      linearTrackColor: KestrelColors.screenBg,
    ),
    textTheme: const TextTheme(
      // Große Zahlen (Budget-Hero, Price-Hero)
      displayMedium: TextStyle(
        color: KestrelColors.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
      // Dashboard Budget-Zahl
      displaySmall: TextStyle(
        color: KestrelColors.textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.0,
      ),
      // Ticker, Card-Werte
      titleMedium: TextStyle(
        color: KestrelColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: KestrelColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      // Standard-Text
      bodyMedium: TextStyle(
        color: KestrelColors.textGrey,
        fontSize: 12,
      ),
      bodySmall: TextStyle(
        color: KestrelColors.textGrey,
        fontSize: 10,
      ),
      // Sublabels, Timestamps
      labelSmall: TextStyle(
        color: KestrelColors.textDimmed,
        fontSize: 9,
      ),
    ),
  );
}

// ── Kestrel Card Label Style ──────────────────────────────────
// Convenience – überall gleich verwenden

const kCardLabelStyle = TextStyle(
  color: KestrelColors.gold,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.8,
);

// ── Kestrel Card Decoration ───────────────────────────────────

BoxDecoration kCardDecoration({bool goldTop = false}) => BoxDecoration(
  color: KestrelColors.cardBg,
  borderRadius: BorderRadius.circular(12),
  border: goldTop
      ? Border(
    top:    const BorderSide(color: KestrelColors.gold,        width: 2),
    left:   const BorderSide(color: KestrelColors.cardBorder),
    right:  const BorderSide(color: KestrelColors.cardBorder),
    bottom: const BorderSide(color: KestrelColors.cardBorder),
  )
      : Border.all(color: KestrelColors.cardBorder),
);

BoxDecoration kInnerCellDecoration() => BoxDecoration(
  color: KestrelColors.innerBg,
  borderRadius: BorderRadius.circular(7),
  border: Border.all(color: KestrelColors.cardBorder),
);

// ── Preisformatierung ─────────────────────────────────────────
// Europäische Schreibweise: 1.234,56 €  (Punkt=Tausender, Komma=Dezimal)
// Nachkommastellen: immer 2, außer bei ganzen Zahlen (dann ebenfalls 2)
// Beispiele: 112.45 → "112,45 €" | 104.2 → "104,20 €" | 1234.5 → "1.234,50 €"

String fmtPrice(num? value, {bool showSign = false}) {
  if (value == null) return '– €';
  final sign   = showSign && value > 0 ? '+' : '';
  final abs    = value.abs();
  final parts  = abs.toStringAsFixed(2).split('.');          // e.g. ["112", "45"]
  final intPart= parts[0];
  final decPart= parts[1];

  // Tausender-Punkte einfügen
  final buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }

  final formatted = '$sign${value < 0 ? '-' : ''}${buf.toString()},$decPart €';
  return formatted;
}

/// Prozent-Formatierung: +7,87 % | -1,82 %
String fmtPct(num? value, {bool showSign = true}) {
  if (value == null) return '– %';
  final sign = showSign && value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2).replaceAll('.', ',')} %';
}

// ── Gold Top Card ─────────────────────────────────────────────
// Flutter erlaubt kein borderRadius + non-uniform Border.
// Lösung: ClipRRect für Radius, Container-Linie für Gold oben.

class GoldTopCard extends StatelessWidget {
  final Widget child;
  const GoldTopCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: KestrelColors.cardBg,
          border: Border.all(color: KestrelColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 2, color: KestrelColors.gold),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Kestrel Logo Widget ───────────────────────────────────────
// Verwendet assets/images/icon_square.png
// size: 26 für AppBar-Hauptscreen, 22 für Detail-Screens mit Back-Button

class KestrelLogo extends StatelessWidget {
  final double size;
  const KestrelLogo({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.23),
      child: Image.asset(
        'assets/images/icon_square.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class KGoldTopCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const KGoldTopCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(13, 11, 13, 13),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color:        KestrelColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: KestrelColors.cardBorder),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(height: 2, color: KestrelColors.gold),
            ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}