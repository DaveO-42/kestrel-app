import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// KestrelColors aus dashboard_screen importieren — oder hier wiederholen
// (In Produktion: auslagern in lib/theme/kestrel_colors.dart)
class KestrelColors {
  static const screenBg    = Color(0xFF0F1822);
  static const cardBg      = Color(0xFF1B2A3E);
  static const cardBorder  = Color(0xFF2E4A6A);
  static const innerBg     = Color(0xFF0F1822);
  static const appBarBg    = Color(0xFF131F2E);

  static const gold        = Color(0xFFC9A84C);
  static const goldLight   = Color(0xFFF0D080);

  static const textPrimary = Color(0xFFE8EEF8);
  static const textGrey    = Color(0xFFC8D4E8);
  static const textDimmed  = Color(0xFF6A8AAA);
  static const textHint    = Color(0xFF334D68);

  static const green       = Color(0xFF27C97A);
  static const red         = Color(0xFFE84040);
  static const orange      = Color(0xFFE07820);
}

// ── Position Detail Screen ────────────────────────────────────

class PositionDetailScreen extends StatefulWidget {
  final String ticker;
  const PositionDetailScreen({super.key, required this.ticker});

  @override
  State<PositionDetailScreen> createState() => _PositionDetailScreenState();
}

class _PositionDetailScreenState extends State<PositionDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getPosition(widget.ticker);
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: KestrelColors.screenBg,
        body: Center(child: CircularProgressIndicator(color: KestrelColors.gold)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: KestrelColors.screenBg,
        body: Center(
          child: Text('Fehler: $_error',
              style: const TextStyle(color: KestrelColors.textGrey)),
        ),
      );
    }

    final p      = _data!;
    final pnl    = p['pnl_eur']  as num?;
    final pnlPct = p['pnl_pct']  as num?;
    final isPos  = (pnl ?? 0) >= 0;
    final signals = p['signals'] as List;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: AppBar(
        backgroundColor: KestrelColors.appBarBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: KestrelColors.textDimmed, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            _KestrelLogo(size: 22),
            const SizedBox(width: 8),
            Text(
              p['ticker'] as String,
              style: const TextStyle(
                color: KestrelColors.goldLight,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: KestrelColors.textDimmed),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: KestrelColors.cardBorder),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Price Hero ─────────────────────────────────────
          _PriceHero(position: p, pnl: pnl, pnlPct: pnlPct, isPositive: isPos),

          // ── Range Bar ──────────────────────────────────────
          _RangeBar(position: p, isPositive: isPos),

          // ── Karten ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            child: Column(
              children: [
                _TradeParamsCard(position: p),
                if (signals.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SignalsCard(signals: signals),
                ],
                if (p['notes'] != null) ...[
                  const SizedBox(height: 8),
                  _KatalysatorCard(notes: p['notes'] as String),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Price Hero ────────────────────────────────────────────────

class _PriceHero extends StatelessWidget {
  final Map<String, dynamic> position;
  final num? pnl;
  final num? pnlPct;
  final bool isPositive;
  const _PriceHero({
    required this.position,
    required this.pnl,
    required this.pnlPct,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final price = position['last_known_price_eur'];
    final pnlColor = isPositive ? KestrelColors.green : KestrelColors.red;
    final pnlSign  = isPositive ? '+' : '';

    return Container(
      color: KestrelColors.appBarBg,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        children: [
          Text(
            (position['ticker'] as String).toUpperCase(),
            style: const TextStyle(
              color: KestrelColors.textDimmed,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price != null ? '€$price' : '–',
            style: const TextStyle(
              color: KestrelColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          if (pnl != null)
            Text(
              '$pnlSign€${pnl!.toStringAsFixed(2)} · $pnlSign${pnlPct?.toStringAsFixed(2)}%',
              style: TextStyle(
                color: pnlColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (position['price_updated_at'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Stand: ${position['price_updated_at']}',
              style: const TextStyle(
                color: KestrelColors.textHint,
                fontSize: 9,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Range Bar ─────────────────────────────────────────────────

class _RangeBar extends StatelessWidget {
  final Map<String, dynamic> position;
  final bool isPositive;
  const _RangeBar({required this.position, required this.isPositive});

  /// Entry-Position auf der Bar berechnen:
  /// Stop-Dot bei 8%, Kurs-Dot bei 92%, Entry relativ dazwischen
  double _entryPosition() {
    final entry = (position['entry_price_eur']  as num?)?.toDouble() ?? 0;
    final stop  = (position['current_stop_eur'] as num?)?.toDouble() ?? 0;
    final price = (position['last_known_price_eur'] as num?)?.toDouble() ?? entry;

    final spanne = price - stop;
    if (spanne <= 0) return 0.5;
    final rel = (entry - stop) / spanne;
    return (0.08 + rel * 0.84).clamp(0.09, 0.91);
  }

  @override
  Widget build(BuildContext context) {
    final entry  = position['entry_price_eur']  as num?;
    final stop   = position['current_stop_eur'] as num?;
    final price  = position['last_known_price_eur'] as num?;
    final entryPos = _entryPosition(); // 0.0–1.0

    final stopDotPos  = 0.08;
    final priceDotPos = 0.92;
    final entryDotPos = entryPos;

    // Farben je nach Zustand
    final priceColor = isPositive ? KestrelColors.green : KestrelColors.orange;
    final priceLabel = price != null ? '€${price.toStringAsFixed(2)}' : '–';
    final entryLabel = entry != null ? 'Entry €${entry.toStringAsFixed(2)}' : '–';
    final stopLabel  = stop  != null ? 'Stop €${stop.toStringAsFixed(2)}' : '–';

    return Container(
      color: KestrelColors.appBarBg,
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 14),
      child: Column(
        children: [
          // Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(stopLabel,
                  style: const TextStyle(
                      color: KestrelColors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
              Text(isPositive ? priceLabel : entryLabel,
                  style: TextStyle(
                      color: isPositive ? priceColor : KestrelColors.textGrey,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
              Text(isPositive ? entryLabel : priceLabel,
                  style: TextStyle(
                      color: isPositive ? KestrelColors.textGrey : priceColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),

          // Track
          SizedBox(
            height: 20, // Höhe für Dots mit Glow
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Track-Hintergrund
                    Positioned.fill(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: KestrelColors.cardBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    // Zonen-Farben
                    if (isPositive) ...[
                      // Stop-Zone: 0 → Stop-Dot
                      _Zone(
                        left: 0,
                        width: w * stopDotPos,
                        color: KestrelColors.red.withOpacity(0.75),
                        roundLeft: true,
                      ),
                      // Risikopuffer: Stop-Dot → Entry-Dot
                      _Zone(
                        left: w * stopDotPos,
                        width: w * (entryDotPos - stopDotPos),
                        color: KestrelColors.red.withOpacity(0.22),
                      ),
                      // Gewinn: Entry-Dot → Kurs-Dot
                      _Zone(
                        left: w * entryDotPos,
                        width: w * (priceDotPos - entryDotPos),
                        color: KestrelColors.green.withOpacity(0.82),
                      ),
                    ] else ...[
                      // Stop-Zone
                      _Zone(
                        left: 0,
                        width: w * stopDotPos,
                        color: KestrelColors.red.withOpacity(0.75),
                        roundLeft: true,
                      ),
                      // Verlust-Terrain: Stop → Kurs
                      _Zone(
                        left: w * stopDotPos,
                        width: w * (entryDotPos - stopDotPos),
                        color: KestrelColors.red.withOpacity(0.50),
                      ),
                      // Offen bis Entry: Kurs → Entry
                      _Zone(
                        left: w * entryDotPos,
                        width: w * (priceDotPos - entryDotPos),
                        color: KestrelColors.orange.withOpacity(0.45),
                      ),
                    ],

                    // Dots
                    _Dot(left: w * stopDotPos,  color: KestrelColors.red,         glow: false),
                    if (isPositive) ...[
                      _Dot(left: w * entryDotPos,  color: KestrelColors.textDimmed, glow: false),
                      _Dot(left: w * priceDotPos,  color: KestrelColors.green,      glow: true),
                    ] else ...[
                      _Dot(left: w * entryDotPos,  color: KestrelColors.orange,     glow: true),
                      _Dot(left: w * priceDotPos,  color: KestrelColors.textDimmed, glow: false),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Zone extends StatelessWidget {
  final double left;
  final double width;
  final Color color;
  final bool roundLeft;
  const _Zone({
    required this.left,
    required this.width,
    required this.color,
    this.roundLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      width: width.clamp(0.0, double.infinity),
      height: 8,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: roundLeft
              ? const BorderRadius.horizontal(left: Radius.circular(4))
              : null,
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double left;
  final Color color;
  final bool glow;
  const _Dot({required this.left, required this.color, required this.glow});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left - 6,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: KestrelColors.appBarBg, width: 2),
          boxShadow: glow
              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, spreadRadius: 2)]
              : null,
        ),
      ),
    );
  }
}

// ── Trade-Parameter Card ──────────────────────────────────────

class _TradeParamsCard extends StatelessWidget {
  final Map<String, dynamic> position;
  const _TradeParamsCard({required this.position});

  @override
  Widget build(BuildContext context) {
    final stopMode = position['stop_mode'] as String? ?? 'normal';
    final isWarn   = stopMode == 'warn';

    return _KestrelCard(
      label: 'TRADE-PARAMETER',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _ParamCell(value: '€${position['entry_price_eur']}', label: 'Entry')),
              const SizedBox(width: 6),
              Expanded(child: _ParamCell(value: '${position['quantity']}',         label: 'Stück')),
              const SizedBox(width: 6),
              Expanded(child: _ParamCell(value: '€${position['atr_at_entry_eur']}', label: 'ATR')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _ParamCell(value: '€${position['initial_stop_eur']}',  label: 'Stop init.')),
              const SizedBox(width: 6),
              Expanded(child: _ParamCell(value: '€${position['current_stop_eur']}',  label: 'Stop akt.')),
              const SizedBox(width: 6),
              Expanded(child: _ParamCell(value: '€${position['highest_close_eur']}', label: 'Höchstkurs')),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: KestrelColors.cardBorder),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Stop-Modus',
                style: TextStyle(color: KestrelColors.textGrey, fontSize: 10),
              ),
              _StopModeBadge(isWarn: isWarn),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParamCell extends StatelessWidget {
  final String value;
  final String label;
  const _ParamCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KestrelColors.screenBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: KestrelColors.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: KestrelColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: KestrelColors.textGrey, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _StopModeBadge extends StatelessWidget {
  final bool isWarn;
  const _StopModeBadge({required this.isWarn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isWarn ? const Color(0xFF201208) : const Color(0xFF1E1408),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isWarn ? const Color(0xFF704010) : const Color(0xFF8A6E2A),
        ),
      ),
      child: Text(
        isWarn ? 'WARN ATR×1.0' : 'Normal ATR×2.0',
        style: TextStyle(
          color: isWarn ? KestrelColors.orange : KestrelColors.gold,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Signale Card ──────────────────────────────────────────────

class _SignalsCard extends StatelessWidget {
  final List signals;
  const _SignalsCard({required this.signals});

  @override
  Widget build(BuildContext context) {
    return _KestrelCard(
      label: 'SIGNALE',
      child: Column(
        children: signals.asMap().entries.map((entry) {
          final isFirst = entry.key == 0;
          return Column(
            children: [
              if (!isFirst)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Divider(height: 1, color: KestrelColors.cardBorder),
                ),
              if (!isFirst) const SizedBox(height: 0),
              _SignalRow(signal: entry.value as Map<String, dynamic>),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  final Map<String, dynamic> signal;
  const _SignalRow({required this.signal});

  Color _color(String sev) {
    switch (sev) {
      case 'HARD': return KestrelColors.red;
      case 'WARN': return KestrelColors.orange;
      default:     return const Color(0xFF78B0E8);
    }
  }

  Color _bgColor(String sev) {
    switch (sev) {
      case 'HARD': return const Color(0xFF200808);
      case 'WARN': return const Color(0xFF201208);
      default:     return const Color(0xFF081828);
    }
  }

  Color _borderColor(String sev) {
    switch (sev) {
      case 'HARD': return const Color(0xFF702020);
      case 'WARN': return const Color(0xFF704010);
      default:     return const Color(0xFF285888);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sev = signal['severity'] as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _bgColor(sev),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _borderColor(sev)),
            ),
            child: Text(
              sev,
              style: TextStyle(
                color: _color(sev),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              signal['message'] as String,
              style: const TextStyle(
                color: KestrelColors.textGrey,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Katalysator Card ──────────────────────────────────────────

class _KatalysatorCard extends StatelessWidget {
  final String notes;
  const _KatalysatorCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return _KestrelCard(
      label: 'KATALYSATOR',
      child: Text(
        notes,
        style: const TextStyle(
          color: KestrelColors.textGrey,
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }
}

// ── Generic Kestrel Card ──────────────────────────────────────

class _KestrelCard extends StatelessWidget {
  final String label;
  final Widget child;
  const _KestrelCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KestrelColors.cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: KestrelColors.gold,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── Kestrel Logo (identisch zu dashboard_screen) ──────────────

class _KestrelLogo extends StatelessWidget {
  final double size;
  const _KestrelLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LogoPainter(),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()..color = KestrelColors.cardBg;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.23));
    canvas.drawRRect(rrect, bgPaint);

    final arrowPaint = Paint()
      ..color = KestrelColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.077
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final s = size.width / 26;
    final arrowPath = Path()
      ..moveTo(4 * s, 18 * s)
      ..lineTo(9 * s, 13 * s)
      ..lineTo(13 * s, 16 * s)
      ..lineTo(22 * s, 7 * s);
    canvas.drawPath(arrowPath, arrowPaint);

    final arrowHead = Path()
      ..moveTo(18 * s, 7 * s)
      ..lineTo(22 * s, 7 * s)
      ..lineTo(22 * s, 11 * s);
    canvas.drawPath(arrowHead, arrowPaint);

    final birdPaint = Paint()
      ..color = KestrelColors.textGrey.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final birdPath = Path();
    birdPath.moveTo(10 * s, 12 * s);
    birdPath.cubicTo(9 * s, 10 * s, 8 * s, 8 * s, 10 * s, 7 * s);
    birdPath.cubicTo(11 * s, 6 * s, 13 * s, 7 * s, 13 * s, 9 * s);
    birdPath.cubicTo(14 * s, 7 * s, 16 * s, 6 * s, 17 * s, 7 * s);
    birdPath.cubicTo(19 * s, 8 * s, 18 * s, 11 * s, 16 * s, 12 * s);
    birdPath.cubicTo(15 * s, 13 * s, 14 * s, 13 * s, 13 * s, 14 * s);
    birdPath.cubicTo(12 * s, 15 * s, 11 * s, 15 * s, 10 * s, 14 * s);
    birdPath.close();
    canvas.drawPath(birdPath, birdPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}