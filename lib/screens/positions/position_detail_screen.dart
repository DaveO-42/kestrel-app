import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/kestrel_theme.dart';

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

    final p       = _data!;
    final pnl     = p['pnl_eur']  as num?;
    final pnlPct  = p['pnl_pct']  as num?;
    final isPos   = (pnl ?? 0) >= 0;
    final signals = p['signals']  as List;

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
            KestrelLogo(size: 22),
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
            icon: const Icon(Icons.refresh, color: KestrelColors.textDimmed),
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
          _PriceHero(position: p, pnl: pnl, pnlPct: pnlPct, isPositive: isPos),
          _RangeBar(position: p, isPositive: isPos),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
    final price    = position['last_known_price_eur'];
    final pnlColor = isPositive ? KestrelColors.green : KestrelColors.red;

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
            price != null ? fmtPrice(price as num) : '– €',
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
              '${fmtPrice(pnl, showSign: true)} · ${fmtPct(pnlPct)}',
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
              style: const TextStyle(color: KestrelColors.textHint, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Range Bar ─────────────────────────────────────────────────

// Zone-Farben als direkte ARGB-Werte statt withOpacity (deprecated in Flutter 3.x)
const _kRedFull    = Color(0xBFE84040); // red   opacity ~0.75
const _kRedDim     = Color(0x38E84040); // red   opacity ~0.22
const _kRedMid     = Color(0x80E84040); // red   opacity ~0.50
const _kGreenFull  = Color(0xD127C97A); // green opacity ~0.82
const _kOrangeDim  = Color(0x73E07820); // orange opacity ~0.45

class _RangeBar extends StatelessWidget {
  final Map<String, dynamic> position;
  final bool isPositive;
  const _RangeBar({required this.position, required this.isPositive});

  double _entryPos() {
    final entry = (position['entry_price_eur']      as num?)?.toDouble() ?? 0;
    final stop  = (position['current_stop_eur']     as num?)?.toDouble() ?? 0;
    final price = (position['last_known_price_eur'] as num?)?.toDouble() ?? entry;
    final spanne = price - stop;
    if (spanne <= 0) return 0.5;
    final rel = (entry - stop) / spanne;
    return (0.08 + rel * 0.84).clamp(0.09, 0.91);
  }

  @override
  Widget build(BuildContext context) {
    final entry    = position['entry_price_eur']      as num?;
    final stop     = position['current_stop_eur']     as num?;
    final price    = position['last_known_price_eur'] as num?;
    final entryPos = _entryPos();

    const stopPos  = 0.08;
    const pricePos = 0.92;

    final priceColor = isPositive ? KestrelColors.green : KestrelColors.orange;
    final priceLabel = fmtPrice(price);
    final entryLabel = entry != null ? 'Entry ${fmtPrice(entry)}' : '–';
    final stopLabel  = stop  != null ? 'Stop ${fmtPrice(stop)}' : '–';

    return Container(
      color: KestrelColors.appBarBg,
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(stopLabel,
                  style: const TextStyle(
                      color: KestrelColors.red, fontSize: 10, fontWeight: FontWeight.w600)),
              Text(isPositive ? priceLabel : entryLabel,
                  style: TextStyle(
                      color: isPositive ? priceColor : KestrelColors.textGrey,
                      fontSize: 10, fontWeight: FontWeight.w600)),
              Text(isPositive ? entryLabel : priceLabel,
                  style: TextStyle(
                      color: isPositive ? KestrelColors.textGrey : priceColor,
                      fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 20,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Track
                    Positioned.fill(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: KestrelColors.cardBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    // Zonen
                    if (isPositive) ...[
                      _Zone(left: 0,                  width: w * stopPos,                color: _kRedFull,   roundLeft: true),
                      _Zone(left: w * stopPos,         width: w * (entryPos - stopPos),   color: _kRedDim),
                      _Zone(left: w * entryPos,        width: w * (pricePos - entryPos),  color: _kGreenFull),
                    ] else ...[
                      _Zone(left: 0,                  width: w * stopPos,                color: _kRedFull,   roundLeft: true),
                      _Zone(left: w * stopPos,         width: w * (entryPos - stopPos),   color: _kRedMid),
                      _Zone(left: w * entryPos,        width: w * (pricePos - entryPos),  color: _kOrangeDim),
                    ],
                    // Dots
                    _Dot(left: w * stopPos,  color: KestrelColors.red,         glow: false),
                    if (isPositive) ...[
                      _Dot(left: w * entryPos,  color: KestrelColors.textDimmed, glow: false),
                      _Dot(left: w * pricePos,  color: KestrelColors.green,      glow: true),
                    ] else ...[
                      _Dot(left: w * entryPos,  color: KestrelColors.orange,     glow: true),
                      _Dot(left: w * pricePos,  color: KestrelColors.textDimmed, glow: false),
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
  const _Zone({required this.left, required this.width, required this.color, this.roundLeft = false});

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
    // Glow ebenfalls ohne withOpacity: feste ARGB-Werte
    final glowColor = glow
        ? Color((0x66000000 | (color.value & 0x00FFFFFF)))
        : null;

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
              ? [BoxShadow(color: glowColor!, blurRadius: 6, spreadRadius: 2)]
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
              Expanded(child: _ParamCell(value: fmtPrice(position['entry_price_eur'] as num?),   label: 'Entry')),
              const SizedBox(width: 6),
              Expanded(child: _ParamCell(value: '${position['quantity']}',                        label: 'Stück')),
              const SizedBox(width: 6),
              Expanded(child: _ParamCell(value: fmtPrice(position['atr_at_entry_eur'] as num?),  label: 'ATR')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _ParamCell(value: fmtPrice(position['initial_stop_eur']  as num?), label: 'Stop init.')),
              const SizedBox(width: 6),
              Expanded(child: _ParamCell(value: fmtPrice(position['current_stop_eur']  as num?), label: 'Stop akt.')),
              const SizedBox(width: 6),
              Expanded(child: _ParamCell(value: fmtPrice(position['highest_close_eur'] as num?), label: 'Höchstkurs')),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: KestrelColors.cardBorder),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Stop-Modus',
                  style: TextStyle(color: KestrelColors.textGrey, fontSize: 10)),
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
          Text(value,
              style: const TextStyle(
                  color: KestrelColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: KestrelColors.textGrey, fontSize: 9)),
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
        color: isWarn ? KestrelColors.orangeBg : KestrelColors.goldBg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isWarn ? KestrelColors.orangeBorder : KestrelColors.goldBorder,
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
          return Column(
            children: [
              if (entry.key > 0) ...[
                const Divider(height: 1, color: KestrelColors.cardBorder),
                const SizedBox(height: 8),
              ],
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
      default:     return KestrelColors.infoText;
    }
  }

  Color _bgColor(String sev) {
    switch (sev) {
      case 'HARD': return KestrelColors.redBg;
      case 'WARN': return KestrelColors.orangeBg;
      default:     return KestrelColors.infoBg;
    }
  }

  Color _borderColor(String sev) {
    switch (sev) {
      case 'HARD': return KestrelColors.redBorder;
      case 'WARN': return KestrelColors.orangeBorder;
      default:     return KestrelColors.infoBorder;
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
            child: Text(sev,
                style: TextStyle(
                    color: _color(sev), fontSize: 9, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(signal['message'] as String,
                style: const TextStyle(
                    color: KestrelColors.textGrey, fontSize: 11, height: 1.4)),
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
      child: Text(notes,
          style: const TextStyle(
              color: KestrelColors.textGrey, fontSize: 11, height: 1.5)),
    );
  }
}

// ── Generic Card ──────────────────────────────────────────────

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
          Text(label, style: kCardLabelStyle),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// KestrelLogo kommt aus kestrel_theme.dart → KestrelLogo(size: 22)