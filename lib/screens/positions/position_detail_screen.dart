import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/sold_sheet.dart';

class PositionDetailScreen extends StatefulWidget {
  final String ticker;
  const PositionDetailScreen({super.key, required this.ticker});

  @override
  State<PositionDetailScreen> createState() => _PositionDetailScreenState();
}

class _PositionDetailScreenState extends State<PositionDetailScreen> {
  CachedResult<Map<String, dynamic>>? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.getPosition(widget.ticker);
      if (!mounted) return;
      setState(() { _result = result; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _result = null; _loading = false; });
    }
  }

  void _openSoldSheet(Map<String, dynamic> position) {
    SoldSheet.show(
      context,
      ticker:              position['ticker'] as String,
      entryPriceEur:       (position['entry_price_eur']      as num).toDouble(),
      quantity:            (position['quantity']             as num).toInt(),
      lastKnownPriceEur:   (position['last_known_price_eur'] as num).toDouble(),
      onSuccess: () {
        // Position geschlossen → zurück zum Dashboard
        Navigator.of(context).pop();
        KestrelNav.of(context)?.goToDashboard();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: KestrelColors.screenBg,
        body: Center(child: CircularProgressIndicator(color: KestrelColors.gold)),
      );
    }

    if (_result == null) {
      return Scaffold(
        backgroundColor: KestrelColors.screenBg,
        appBar: AppBar(
          backgroundColor: KestrelColors.appBarBg,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: KestrelColors.textDimmed, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.ticker,
              style: const TextStyle(color: KestrelColors.goldLight,
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        body: const Center(
          child: Text('Keine Verbindung und kein Cache verfügbar.',
              style: TextStyle(color: KestrelColors.textGrey)),
        ),
      );
    }

    final p       = _result!.data;
    final pnl     = p['pnl_eur']  as num?;
    final pnlPct  = p['pnl_pct']  as num?;
    final isPos   = (pnl ?? 0) >= 0;
    final signals = p['signals']  as List? ?? [];

    final hasHard = signals.any((s) => (s as Map)['severity'] == 'HARD');
    final hasWarn = signals.any((s) => (s as Map)['severity'] == 'WARN');

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
            onPressed: () { setState(() => _loading = true); _load(); },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: KestrelColors.cardBorder),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(
              bottom: 88 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              if (_result!.isOffline)
                OfflineBanner(cachedAt: _result!.cachedAt),
              if (hasHard) const _HardBanner(),
              _PriceHero(position: p, pnl: pnl, pnlPct: pnlPct, isPositive: isPos),
              _RangeBar(position: p, isPositive: isPos),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TradeParamsCard(position: p),
                    if (signals.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _SignalsCard(signals: signals, hasWarn: hasWarn, hasHard: hasHard),
                    ],
                    if (p['notes'] != null && (p['notes'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _KatalysatorCard(notes: p['notes'] as String),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
          // ── Sticky Sell Button ─────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SellButton(
              onTap: () => _openSoldSheet(p),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────

String fmtPrice(num? v, {bool showSign = false}) {
  if (v == null) return '–';
  final sign = showSign && v > 0 ? '+' : '';
  final abs = v.abs();
  final parts = abs.toStringAsFixed(2).split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  return '$sign${v < 0 ? '-' : ''}${buf.toString()},$decPart €';
}

String fmtPct(num? v, {bool showSign = true}) {
  if (v == null) return '–';
  final sign = showSign && v > 0 ? '+' : '';
  return '$sign${v.toStringAsFixed(2).replaceAll('.', ',')} %';
}

const kCardLabelStyle = TextStyle(
  color: KestrelColors.gold,
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.8,
);

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

  String _fmtTimestamp(String? iso) {
    if (iso == null || iso.length < 16) return '–';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.'
        '${l.month.toString().padLeft(2, '0')}.'
        '${l.year}, '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')} Uhr';
  }

  @override
  Widget build(BuildContext context) {
    final price     = position['last_known_price_eur'];
    final updatedAt = position['price_updated_at'] as String?;
    final pnlColor  = isPositive ? KestrelColors.green : KestrelColors.red;

    return Container(
      color: KestrelColors.appBarBg,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        children: [
          Text(
            (position['ticker'] as String).toUpperCase(),
            style: const TextStyle(
              color: KestrelColors.textDimmed,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price != null ? fmtPrice(price as num) : '–',
            style: const TextStyle(
              color: KestrelColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Entry ${fmtPrice(position['entry_price_eur'] as num?)}',
                style: const TextStyle(
                    color: KestrelColors.textDimmed, fontSize: 11),
              ),
              if (pnl != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? KestrelColors.greenBg
                        : KestrelColors.redBg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isPositive
                          ? KestrelColors.greenBorder
                          : KestrelColors.redBorder,
                    ),
                  ),
                  child: Text(
                    '${fmtPrice(pnl, showSign: true)}  ${fmtPct(pnlPct)}',
                    style: TextStyle(
                      color: pnlColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (updatedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              _fmtTimestamp(updatedAt),
              style: const TextStyle(
                  color: KestrelColors.textHint, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Range Bar ─────────────────────────────────────────────────

const _kRedFull   = Color(0xFFE84040);
const _kRedDim    = Color(0x33E84040);
const _kRedMid    = Color(0x66E84040);
const _kGreenFull = Color(0xFF27C97A);
const _kOrangeDim = Color(0x55E07820);

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

    final stopLabel  = stop  != null ? 'Stop ${fmtPrice(stop)}'   : '–';
    final entryLabel = entry != null ? 'Entry ${fmtPrice(entry)}' : '–';
    final priceLabel = price != null ? 'Kurs ${fmtPrice(price)}'  : 'Kurs –';

    return Container(
      color: KestrelColors.appBarBg,
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(stopLabel,
                  style: const TextStyle(color: KestrelColors.red,
                      fontSize: 10, fontWeight: FontWeight.w600)),
              Text(entryLabel,
                  style: const TextStyle(color: KestrelColors.textGrey,
                      fontSize: 10, fontWeight: FontWeight.w600)),
              Text(priceLabel,
                  style: TextStyle(color: priceColor,
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
                    Positioned.fill(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: KestrelColors.cardBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    if (isPositive) ...[
                      _Zone(left: 0,            width: w * stopPos,               color: _kRedFull, roundLeft: true),
                      _Zone(left: w * stopPos,  width: w * (entryPos - stopPos),  color: _kRedDim),
                      _Zone(left: w * entryPos, width: w * (pricePos - entryPos), color: _kGreenFull),
                    ] else ...[
                      _Zone(left: 0,            width: w * stopPos,               color: _kRedFull, roundLeft: true),
                      _Zone(left: w * stopPos,  width: w * (entryPos - stopPos),  color: _kRedMid),
                      _Zone(left: w * entryPos, width: w * (pricePos - entryPos), color: _kOrangeDim),
                    ],
                    _Dot(left: w * stopPos,  color: KestrelColors.red,          glow: false),
                    if (isPositive) ...[
                      _Dot(left: w * entryPos, color: KestrelColors.textDimmed, glow: false),
                      _Dot(left: w * pricePos, color: KestrelColors.green,      glow: true),
                    ] else ...[
                      _Dot(left: w * entryPos, color: KestrelColors.orange,     glow: true),
                      _Dot(left: w * pricePos, color: KestrelColors.textDimmed, glow: false),
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
  const _Zone({required this.left, required this.width,
    required this.color, this.roundLeft = false});

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
    final glowColor = Color((0x66000000 | (color.value & 0x00FFFFFF)));
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
              ? [BoxShadow(color: glowColor, blurRadius: 6, spreadRadius: 2)]
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

  String _positionSize(Map<String, dynamic> p) {
    final price = (p['last_known_price_eur'] as num?)?.toDouble();
    final qty   = (p['quantity']             as num?)?.toDouble();
    if (price == null || qty == null) return '–';
    return fmtPrice(price * qty);
  }

  String _stopDistanz(Map<String, dynamic> p) {
    final price = (p['last_known_price_eur'] as num?)?.toDouble();
    final stop  = (p['current_stop_eur']     as num?)?.toDouble();
    if (price == null || stop == null || price <= 0) return '–';
    final pct = (price - stop) / price * 100;
    return '−${pct.toStringAsFixed(1)} %';
  }

  String _fmtEntryDate(String? iso) {
    if (iso == null || iso.length < 10) return '–';
    final parts = iso.substring(0, 10).split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  String _holdDays(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final days = DateTime.now().difference(dt).inDays;
    return 'vor $days Tag${days == 1 ? '' : 'en'}';
  }

  @override
  Widget build(BuildContext context) {
    final stopMode  = position['stop_mode'] as String? ?? 'normal';
    final isWarn    = stopMode == 'warn';
    final entryDate = position['entry_date'] as String?;

    return _KestrelCard(
      label: 'TRADE-PARAMETER',
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _ParamCell(
                value: fmtPrice(position['entry_price_eur'] as num?),
                label: 'Entry')),
            const SizedBox(width: 6),
            Expanded(child: _ParamCell(
                value: '${position['quantity']}',
                label: 'Stück')),
            const SizedBox(width: 6),
            Expanded(child: _ParamCell(
                value: _positionSize(position),
                label: 'Position')),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _ParamCell(
                value: fmtPrice(position['current_stop_eur'] as num?),
                label: 'Stop akt.')),
            const SizedBox(width: 6),
            Expanded(child: _ParamCell(
                value: _stopDistanz(position),
                label: 'Stop-Distanz',
                dimmed: true)),
            const SizedBox(width: 6),
            Expanded(child: _ParamCell(
                value: fmtPrice(position['atr_at_entry_eur'] as num?),
                label: 'ATR')),
          ]),
          const SizedBox(height: 10),
          Container(height: 1, color: KestrelColors.cardBorder),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('KAUFDATUM',
                        style: TextStyle(color: KestrelColors.textDimmed,
                            fontSize: 9, fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 3),
                    Text(
                      entryDate != null
                          ? '${_fmtEntryDate(entryDate)} · ${_holdDays(entryDate)}'
                          : '–',
                      style: const TextStyle(color: KestrelColors.textPrimary,
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
  final bool dimmed;
  const _ParamCell({required this.value, required this.label, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KestrelColors.screenBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: KestrelColors.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: dimmed ? KestrelColors.textGrey : KestrelColors.textPrimary,
                fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: KestrelColors.textGrey, fontSize: 9)),
      ]),
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
          fontSize: 9, fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Signale Card ──────────────────────────────────────────────

class _SignalsCard extends StatelessWidget {
  final List signals;
  final bool hasWarn;
  final bool hasHard;
  const _SignalsCard({required this.signals, this.hasWarn = false, this.hasHard = false});

  @override
  Widget build(BuildContext context) {
    final borderColor = hasHard
        ? KestrelColors.redBorder
        : hasWarn
        ? KestrelColors.orangeBorder
        : KestrelColors.cardBorder;

    return Container(
      decoration: BoxDecoration(
        color: KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: (hasHard || hasWarn) ? 1.5 : 1),
      ),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SIGNALE', style: kCardLabelStyle),
          const SizedBox(height: 10),
          ...signals.map((s) {
            final sig      = s as Map<String, dynamic>;
            final severity = sig['severity'] as String? ?? 'INFO';
            final message  = sig['message']  as String? ?? '';
            final color = switch (severity) {
              'HARD' => KestrelColors.red,
              'WARN' => KestrelColors.orange,
              _      => KestrelColors.textDimmed,
            };
            final bg = switch (severity) {
              'HARD' => KestrelColors.redBg,
              'WARN' => KestrelColors.orangeBg,
              _      => KestrelColors.screenBg,
            };
            final border = switch (severity) {
              'HARD' => KestrelColors.redBorder,
              'WARN' => KestrelColors.orangeBorder,
              _      => KestrelColors.cardBorder,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: border),
                    ),
                    child: Text(severity,
                        style: TextStyle(color: color, fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(message,
                        style: const TextStyle(
                            color: KestrelColors.textGrey,
                            fontSize: 11, height: 1.4)),
                  ),
                ],
              ),
            );
          }),
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

// ── HARD Banner ───────────────────────────────────────────────

class _HardBanner extends StatelessWidget {
  const _HardBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E0808),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      child: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: KestrelColors.red, size: 13),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'HARD-Signal aktiv – sofortiger Handlungsbedarf',
            style: TextStyle(color: KestrelColors.red,
                fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

// ── Sticky Sell Button ────────────────────────────────────────

class _SellButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SellButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x000F1822), Color(0xFF0F1822)],
          stops: [0.0, 0.45],
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 12 + bottomInset),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: KestrelColors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Verkaufen →',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}