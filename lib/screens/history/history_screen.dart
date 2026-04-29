import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';
import '../../widgets/info_sheet.dart';
import '../../widgets/offline_banner.dart';
import 'trade_detail_screen.dart';

// ── Formatter Helpers ─────────────────────────────────────────

String fmtPrice(num? val, {bool showSign = false}) {
  if (val == null) return '–';
  final sign = showSign && val >= 0 ? '+' : '';
  return '$sign${val.toStringAsFixed(2)} €';
}

String fmtPct(num? val, {bool showSign = true}) {
  if (val == null) return '–';
  final sign = showSign && val >= 0 ? '+' : '';
  return '$sign${val.toStringAsFixed(1)} %';
}

// ── Screen ────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  CachedResult<Map<String, dynamic>>? _summaryResult;
  CachedResult<Map<String, dynamic>>? _historyResult;
  CachedResult<Map<String, dynamic>>? _systemResult;
  CachedResult<Map<String, dynamic>>? _benchmarkResult;
  bool _loading = true;
  bool _infoOpen = false;

  bool get _isOffline =>
      (_summaryResult?.isOffline ?? false) ||
          (_historyResult?.isOffline ?? false);

  DateTime? get _cachedAt => _summaryResult?.cachedAt;

  void _openInfo() {
    setState(() => _infoOpen = true);
    showKestrelInfoSheet(context).then((_) {
      if (mounted) setState(() => _infoOpen = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final summaryFuture   = ApiService.getHistorySummary();
      final historyFuture   = ApiService.getHistory();
      final systemFuture    = ApiService.getSystemStatus();
      final benchmarkFuture = ApiService.getHistoryBenchmark();
      final summary   = await summaryFuture;
      final history   = await historyFuture;
      final system    = await systemFuture;
      // Benchmark ist optional – Fehler dürfen den Screen nicht blocken
      CachedResult<Map<String, dynamic>>? benchmark;
      try { benchmark = await benchmarkFuture; } catch (_) {}
      if (!mounted) return;
      setState(() {
        _summaryResult   = summary;
        _historyResult   = history;
        _systemResult    = system;
        _benchmarkResult = benchmark;
        _loading = false;
      });
      KestrelNav.of(context)?.setConnectionError(_isOffline);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      KestrelNav.of(context)?.setConnectionError(true);
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

    final summary      = _summaryResult?.data;
    final trades       = (_historyResult?.data)?['trades'] as List?;
    final system       = _systemResult?.data;
    final paused       = system?['is_paused'] as bool? ?? false;
    final benchmarkPts = (_benchmarkResult?.data)?['points'] as List?;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isOffline)
            OfflineBanner(cachedAt: _cachedAt),
          if (paused)
            PauseBanner(
              drawdownPct: system?['drawdown_pct'] as num?,
              reason:      system?['pause_reason'] as String?,
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: KestrelColors.gold,
              backgroundColor: KestrelColors.cardBg,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                children: [
                  if (summary != null) _PnlHero(summary: summary),
                  const SizedBox(height: 8),
                  if (trades != null && trades.length >= 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EquityChartCard(
                        trades: trades,
                        benchmarkPoints: benchmarkPts,
                      ),
                    ),
                  if (trades != null) _TradeList(trades: trades),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: KestrelColors.appBarBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 13,
      title: Row(
        children: [
          KestrelLogo(size: 26),
          const SizedBox(width: 8),
          const Text('History',
              style: TextStyle(color: KestrelColors.goldLight, fontSize: 16,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        ],
      ),
      actions: [
        InfoButton(active: _infoOpen, onTap: _openInfo),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: KestrelColors.cardBorder),
      ),
    );
  }
}

// ── P&L Hero ──────────────────────────────────────────────────

class _PnlHero extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _PnlHero({required this.summary});

  @override
  Widget build(BuildContext context) {
    final totalPnl   = (summary['total_pnl_eur']   as num?) ?? 0;
    final winRate    = (summary['win_rate_pct']     as num?) ?? 0;
    final avgReturn  = (summary['avg_return_pct']   as num?) ?? 0;
    final avgHold    = summary['avg_hold_days']     as num?;
    final sharpe     = summary['sharpe_ratio']      as num?;
    final tradeCount = ((summary['trade_count']     as num?) ?? 0).toInt();
    final isPos      = totalPnl >= 0;

    return GoldTopCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TOTAL P&L',
                style: TextStyle(color: KestrelColors.gold, fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Text(
              '${isPos ? '+' : ''}${totalPnl.toStringAsFixed(2)} €',
              style: TextStyle(
                  color: isPos ? KestrelColors.green : KestrelColors.red,
                  fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _StatCell(
                  value: '${winRate.toStringAsFixed(0)} %',
                  label: 'Win-Rate',
                  valueColor: winRate >= 50 ? KestrelColors.green : KestrelColors.red,
                )),
                const SizedBox(width: 6),
                Expanded(child: _StatCell(
                  value: fmtPct(avgReturn),
                  label: 'Ø Return',
                  valueColor: avgReturn >= 0 ? KestrelColors.green : KestrelColors.red,
                )),
                const SizedBox(width: 6),
                Expanded(child: _StatCell(value: '$tradeCount', label: 'Trades')),
                if (sharpe != null) ...[
                  const SizedBox(width: 6),
                  Expanded(child: _StatCell(
                      value: sharpe.toStringAsFixed(2), label: 'Sharpe')),
                ],
                if (avgHold != null) ...[
                  const SizedBox(width: 6),
                  Expanded(child: _StatCell(
                      value: '${avgHold.toStringAsFixed(0)}d', label: 'Ø Hold')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trade List ────────────────────────────────────────────────

class _TradeList extends StatelessWidget {
  final List trades;
  const _TradeList({required this.trades});

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: KestrelColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KestrelColors.cardBorder),
        ),
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text('Noch keine abgeschlossenen Trades',
              style: TextStyle(color: KestrelColors.textGrey, fontSize: 13)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KestrelColors.cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TRADES (${trades.length})',
              style: const TextStyle(color: KestrelColors.gold, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          ...trades.map((t) => _TradeRow(trade: t as Map<String, dynamic>)),
        ],
      ),
    );
  }
}

// ── Trade Row ─────────────────────────────────────────────────

class _TradeRow extends StatelessWidget {
  final Map<String, dynamic> trade;
  const _TradeRow({required this.trade});

  String _fmtDate(String? iso) {
    if (iso == null || iso.length < 10) return '–';
    final parts = iso.substring(0, 10).split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final pnl    = trade['pnl_abs_eur'] as num?;
    final pnlPct = trade['pnl_pct']     as num?;
    final isPos  = (pnl ?? 0) >= 0;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TradeDetailScreen(trade: trade),
        ),
      ),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trade['ticker'] as String? ?? '–',
                  style: const TextStyle(color: KestrelColors.textPrimary,
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(_fmtDate(trade['exit_date'] as String?),
                  style: const TextStyle(color: KestrelColors.textGrey, fontSize: 10)),
            ],
          ),
          if (pnl != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtPrice(pnl, showSign: true),
                    style: TextStyle(
                        color: isPos ? KestrelColors.green : KestrelColors.red,
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(fmtPct(pnlPct),
                    style: TextStyle(
                        color: isPos ? KestrelColors.green : KestrelColors.red,
                        fontSize: 10)),
              ],
            ),
        ],
      ),
    ));
  }
}

// ── Stat Cell ─────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  const _StatCell({required this.value, required this.label, this.valueColor});

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
              style: TextStyle(
                  color: valueColor ?? KestrelColors.textPrimary,
                  fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: KestrelColors.textGrey, fontSize: 9)),
        ],
      ),
    );
  }
}

// ── Equity Chart Card ──────────────────────────────────────────

class _EquityChartCard extends StatelessWidget {
  final List trades;
  final List? benchmarkPoints;
  const _EquityChartCard({required this.trades, this.benchmarkPoints});

  List<double> _buildEquityValues() {
    double cumulative = 0.0;
    return trades.reversed.map((t) {
      cumulative += (t['pnl_abs_eur'] as num).toDouble();
      return cumulative;
    }).toList();
  }

  List<double>? _buildBenchmarkValues() {
    if (benchmarkPoints == null || benchmarkPoints!.isEmpty) return null;
    try {
      return benchmarkPoints!.map((p) => (p as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KestrelColors.cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EQUITY', style: kCardLabelStyle),
          const SizedBox(height: 8),
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(
              painter: _EquityChartPainter(
                equityValues:    _buildEquityValues(),
                benchmarkValues: _buildBenchmarkValues(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Equity Chart Painter ───────────────────────────────────────

class _EquityChartPainter extends CustomPainter {
  final List<double> equityValues;
  final List<double>? benchmarkValues;
  _EquityChartPainter({required this.equityValues, this.benchmarkValues});

  // Dashed polyline mit kontinuierlichem Dash-Pattern über Segmentgrenzen hinweg
  static void _dashedPolyline(Canvas canvas, List<Offset> pts, Paint paint,
      double dashLen, double gapLen) {
    if (pts.length < 2) return;
    double remaining = dashLen;
    bool drawing = true;
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final dx = p1.dx - p0.dx;
      final dy = p1.dy - p0.dy;
      final segLen = math.sqrt(dx * dx + dy * dy);
      if (segLen == 0) continue;
      final ux = dx / segLen;
      final uy = dy / segLen;
      double consumed = 0;
      while (consumed < segLen) {
        final take = math.min(remaining, segLen - consumed);
        if (drawing) {
          canvas.drawLine(
            Offset(p0.dx + ux * consumed,          p0.dy + uy * consumed),
            Offset(p0.dx + ux * (consumed + take), p0.dy + uy * (consumed + take)),
            paint,
          );
        }
        consumed  += take;
        remaining -= take;
        if (remaining == 0) {
          drawing   = !drawing;
          remaining = drawing ? dashLen : gapLen;
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (equityValues.length < 2) return;

    final hasBench = benchmarkValues != null && benchmarkValues!.length >= 2;

    // Gemeinsame Y-Achse aus beiden Kurven
    final allVals = [...equityValues, if (hasBench) ...benchmarkValues!];
    final minVal   = allVals.reduce(math.min);
    final maxVal   = allVals.reduce(math.max);
    const vPad     = 8.0;
    final drawH    = size.height - 2 * vPad;
    final range    = maxVal - minVal;

    double toY(double v) {
      if (range == 0) return size.height / 2;
      return vPad + (1 - (v - minVal) / range) * drawH;
    }

    final lineColor = equityValues.last >= 0 ? KestrelColors.green : KestrelColors.red;
    final baselineY = (minVal < 0 && maxVal > 0) ? toY(0) : (size.height - vPad);
    final n = equityValues.length;

    // 1. Gradient-Fill (nur Equity)
    final fillPath = Path();
    for (int i = 0; i < n; i++) {
      final x = (i / (n - 1)) * size.width;
      final y = toY(equityValues[i]);
      if (i == 0) { fillPath.moveTo(x, y); } else { fillPath.lineTo(x, y); }
    }
    fillPath.lineTo(size.width, baselineY);
    fillPath.lineTo(0, baselineY);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withValues(alpha: 0.18), lineColor.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // 2. Zero-Linie – nur wenn min < 0 < max
    if (minVal < 0 && maxVal > 0) {
      final zeroY = toY(0);
      final zeroPaint = Paint()
        ..color      = KestrelColors.textHint
        ..strokeWidth = 0.8
        ..style      = PaintingStyle.stroke;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, zeroY),
          Offset(math.min(x + 3.0, size.width), zeroY),
          zeroPaint,
        );
        x += 6.0;
      }
    }

    // 3. Benchmark-Linie (gestrichelt, hinter Equity)
    if (hasBench) {
      final bValues = benchmarkValues!;
      final bn = bValues.length;
      final bPts = List.generate(
        bn,
        (i) => Offset((i / (bn - 1)) * size.width, toY(bValues[i])),
      );
      _dashedPolyline(
        canvas, bPts,
        Paint()
          ..color      = const Color(0xFF4A7FA5)
          ..strokeWidth = 1.5
          ..style      = PaintingStyle.stroke
          ..strokeCap  = StrokeCap.round,
        6.0, 3.0,
      );
    }

    // 4. Equity-Linie
    final linePath = Path();
    for (int i = 0; i < n; i++) {
      final x = (i / (n - 1)) * size.width;
      final y = toY(equityValues[i]);
      if (i == 0) { linePath.moveTo(x, y); } else { linePath.lineTo(x, y); }
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color      = lineColor
        ..strokeWidth = 2.0
        ..style      = PaintingStyle.stroke
        ..strokeCap  = StrokeCap.round,
    );

    // 5. Datenpunkte (Equity)
    final dotPaint = Paint()..color = lineColor..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      canvas.drawCircle(
        Offset((i / (n - 1)) * size.width, toY(equityValues[i])),
        3.5, dotPaint,
      );
    }

    // 6. Labels
    void drawLabel(String text, double x, double y, Color color,
        {bool rightAlign = false}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rightAlign ? x - tp.width : x, y - tp.height / 2));
    }

    // "0 €" links am Startpunkt
    drawLabel('0 €', 0, toY(equityValues.first), KestrelColors.textDimmed);

    // Benchmark-Label "QQQ" rechts
    double? benchEndY;
    if (hasBench) {
      benchEndY = toY(benchmarkValues!.last);
      drawLabel('QQQ', size.width, benchEndY,
          const Color(0xFF4A7FA5), rightAlign: true);
    }

    // Equity-Endlabel rechts, ggf. nach oben versetzt bei Überlappung
    final lastVal     = equityValues.last;
    final equityEndY  = toY(lastVal);
    final sign        = lastVal >= 0 ? '+' : '';
    final equityLabel = '$sign${lastVal.toStringAsFixed(2)} €';
    final labelY = (benchEndY != null && (equityEndY - benchEndY).abs() < 15)
        ? math.max(equityEndY - 14, vPad)
        : equityEndY;
    drawLabel(equityLabel, size.width, labelY,
        KestrelColors.textDimmed, rightAlign: true);
  }

  @override
  bool shouldRepaint(_EquityChartPainter old) => true;
}