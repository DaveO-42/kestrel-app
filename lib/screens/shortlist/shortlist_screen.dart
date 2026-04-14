import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';
import '../../widgets/info_sheet.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/bought_sheet.dart';
import 'dart:ui' as ui;

class ShortlistScreen extends StatefulWidget {
  const ShortlistScreen({super.key});

  @override
  State<ShortlistScreen> createState() => _ShortlistScreenState();
}

class _ShortlistScreenState extends State<ShortlistScreen> {
  CachedResult<Map<String, dynamic>>? _dataResult;
  CachedResult<Map<String, dynamic>>? _systemResult;
  bool _loading = true;
  bool _infoOpen = false;

  // V2: Skip-State (lokal, bis nächstem Reload)
  final Set<String> _skipped = {};
  // V2: verfügbares Budget für BoughtSheet
  double? _availableBudget;

  bool get _isOffline => _dataResult?.isOffline ?? false;
  DateTime? get _cachedAt => _dataResult?.cachedAt;

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
      final dataFuture   = ApiService.getShortlist();
      final systemFuture = ApiService.getSystemStatus();
      // V2: Budget parallel laden
      final dashFuture   = ApiService.getDashboard();

      final data   = await dataFuture;
      final system = await systemFuture;
      final dash   = await dashFuture;

      if (!mounted) return;
      setState(() {
        _dataResult      = data;
        _systemResult    = system;
        _availableBudget = (dash.data['budget']?['available_eur'] as num?)?.toDouble();
        _loading         = false;
        // Skip-State bei Reload zurücksetzen
        _skipped.clear();
      });
      KestrelNav.of(context)?.setConnectionError(_isOffline);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      KestrelNav.of(context)?.setConnectionError(true);
    }
  }

  void _onSkip(String ticker) {
    setState(() => _skipped.add(ticker));
  }

  void _onBought() {
    // Nach Kauf Shortlist neu laden → Status wechselt auf confirmed
    _load();
    // Dashboard ebenfalls aktualisieren → neue Position erscheint sofort
    KestrelNav.of(context)?.refreshDashboard();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: KestrelColors.screenBg,
        body: Center(child: CircularProgressIndicator(color: KestrelColors.gold)),
      );
    }

    if (_dataResult == null) {
      return Scaffold(
        backgroundColor: KestrelColors.screenBg,
        appBar: _buildAppBar('–'),
        body: const Column(children: [ErrorBanner()]),
      );
    }

    final data         = _dataResult!.data;
    final system       = _systemResult?.data;
    final status       = data['status']        as String? ?? 'pending';
    final runId        = data['run_id']         as String? ?? '';
    final candidates   = (data['candidates']   as List? ?? [])
        .where((c) => !_skipped.contains((c as Map<String, dynamic>)['ticker']))
        .toList();
    final topCandidate = data['top_candidate'];
    final topTicker    = topCandidate != null
        ? (topCandidate as Map<String, dynamic>)['ticker'] as String?
        : null;
    final runTime      = runId.length >= 13
        ? '${runId.substring(9, 11)}:${runId.substring(11, 13)}'
        : runId;
    final paused       = system?['is_paused'] as bool? ?? false;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: _buildAppBar(status),
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
              child: candidates.isEmpty
                  ? _buildEmpty(status, runId, data)
                  : ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                children: [
                  ...candidates.asMap().entries.map((entry) {
                    final candidate = entry.value as Map<String, dynamic>;
                    final isTop = candidate['ticker'] == topTicker;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: isTop
                          ? _CandidateCard(
                        candidate:        candidate,
                        availableBudget:  _availableBudget ?? 0,
                        onSkip:           _onSkip,
                        onBought:         _onBought,
                      )
                          : _CandidateDimCard(
                        candidate: candidate,
                        index:     entry.key + 1,
                      ),
                    );
                  }),
                  _ShortlistFooter(runTime: runTime, data: data),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(String status) {
    return AppBar(
      backgroundColor: KestrelColors.appBarBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 13,
      title: Row(
        children: [
          KestrelLogo(size: 26),
          const SizedBox(width: 8),
          const Text('Shortlist',
              style: TextStyle(color: KestrelColors.goldLight, fontSize: 16,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _StatusBadge(status: status),
        ),
        InfoButton(active: _infoOpen, onTap: _openInfo),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: KestrelColors.cardBorder),
      ),
    );
  }

  Widget _buildEmpty(String status, String runId, Map<String, dynamic> data) {
    final reason  = data['order_reason'] as String?;
    final runDate = data['run_date']     as String?;
    final runTime = runId.length >= 13
        ? '${runId.substring(9, 11)}:${runId.substring(11, 13)}'
        : null;

    final isBudget  = reason != null && reason.toLowerCase().contains('budget');
    final isPending = status == 'expired' || runDate != _todayString();

    final variant = isPending
        ? _EmptyVariant.pending
        : isBudget
        ? _EmptyVariant.budget
        : _EmptyVariant.none;

    return ListView(
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _ShortlistEmptyState(
            variant: variant,
            subText: isBudget ? reason : null,
            runTime: runTime,
          ),
        ),
      ],
    );
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

// ── Helpers ───────────────────────────────────────────────────

String fmtPrice(num? v, {bool showSign = false}) {
  if (v == null) return '–';
  final sign = showSign && v >= 0 ? '+' : '';
  return '$sign€${v.toStringAsFixed(2)}';
}

String fmtPct(num? v) {
  if (v == null) return '–';
  final sign = v >= 0 ? '+' : '';
  return '$sign${v.toStringAsFixed(1)}%';
}

const kCardLabelStyle = TextStyle(
  color: KestrelColors.gold,
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.8,
);

// ── Status Badge ──────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg, border) = switch (status) {
      'pending'   => ('heute · pending',  KestrelColors.gold,       KestrelColors.goldBg,   KestrelColors.goldBorder),
      'confirmed' => ('bestätigt',        KestrelColors.green,      KestrelColors.greenBg,  KestrelColors.greenBorder),
      'skipped'   => ('übersprungen',     KestrelColors.textDimmed, KestrelColors.screenBg, KestrelColors.cardBorder),
      'expired'   => ('abgelaufen',       KestrelColors.red,        KestrelColors.redBg,    KestrelColors.redBorder),
      _           => (status,             KestrelColors.textDimmed, KestrelColors.screenBg, KestrelColors.cardBorder),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(5),
          border: Border.all(color: border)),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Kandidaten-Card (Top) ─────────────────────────────────────

class _CandidateCard extends StatefulWidget {
  final Map<String, dynamic> candidate;
  final double availableBudget;
  final void Function(String ticker) onSkip;
  final VoidCallback onBought;

  const _CandidateCard({
    required this.candidate,
    required this.availableBudget,
    required this.onSkip,
    required this.onBought,
  });

  @override
  State<_CandidateCard> createState() => _CandidateCardState();
}

class _CandidateCardState extends State<_CandidateCard> {
  bool _skipLoading = false;

  Future<void> _handleSkip(String ticker) async {
    setState(() => _skipLoading = true);
    try {
      await ApiService.postSkip(ticker);
      widget.onSkip(ticker);
    } on ActionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: KestrelColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _skipLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    final ticker = candidate['ticker']             as String;
    final sector = candidate['sector']             as String? ?? '–';
    final score  = candidate['score']              as num?;
    final price  = candidate['price_eur']          as num?;
    final perf4w = candidate['performance_4w_pct'] as num?;
    final rsi    = candidate['rsi']                as num?;
    final claude = candidate['claude']             as Map<String, dynamic>?;
    final params = candidate['trade_params']       as Map<String, dynamic>?;

    return Container(
      decoration: BoxDecoration(
        color: KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KestrelColors.cardBorder),
      ),
      foregroundDecoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        border: Border(top: BorderSide(color: KestrelColors.gold, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Ticker + Score ─────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ticker,
                    style: const TextStyle(color: KestrelColors.textPrimary,
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text(sector,
                    style: const TextStyle(color: KestrelColors.textGrey, fontSize: 10)),
              ]),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: KestrelColors.goldBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: KestrelColors.goldBorder),
                  ),
                  child: Text('Score ${score.toStringAsFixed(2)}',
                      style: const TextStyle(color: KestrelColors.gold,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Metriken ───────────────────────────────────────
          Row(
            children: [
              Expanded(child: _MetricCell(
                  value: price != null ? fmtPrice(price) : '–', label: 'Kurs')),
              const SizedBox(width: 6),
              Expanded(child: _MetricCell(
                  value: perf4w != null ? fmtPct(perf4w) : '–',
                  label: '4W-Perf',
                  valueColor: perf4w != null && perf4w >= 0
                      ? KestrelColors.green : KestrelColors.red)),
              const SizedBox(width: 6),
              Expanded(child: _MetricCell(
                  value: rsi != null ? rsi.toStringAsFixed(1) : '–', label: 'RSI')),
            ],
          ),

          // ── Claude Box ─────────────────────────────────────
          if (claude != null) ...[
            const SizedBox(height: 10),
            _ClaudeBox(claude: claude),
          ],

          // ── Trade-Parameter ────────────────────────────────
          if (params != null) ...[
            const SizedBox(height: 10),
            _TradeParamsRow(params: params),
          ],

          // ── Trennlinie ─────────────────────────────────────
          const SizedBox(height: 14),
          Container(height: 1, color: KestrelColors.cardBorder),
          const SizedBox(height: 12),

          // ── Action-Buttons ─────────────────────────────────
          Row(
            children: [
              // Überspringen
              Expanded(
                child: TextButton(
                  onPressed: _skipLoading
                      ? null
                      : () => _handleSkip(ticker),
                  style: TextButton.styleFrom(
                    foregroundColor: KestrelColors.textDimmed,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: _skipLoading
                      ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KestrelColors.textDimmed,
                    ),
                  )
                      : const Text('Überspringen'),
                ),
              ),
              const SizedBox(width: 10),
              // Kaufen
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    BoughtSheet.show(
                      context,
                      candidate:         widget.candidate,
                      availableBudgetEur: widget.availableBudget,
                      onSuccess:         widget.onBought,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KestrelColors.gold,
                    foregroundColor: const Color(0xFF0F1822),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Kaufen →',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Dim Card ──────────────────────────────────────────────────

class _CandidateDimCard extends StatelessWidget {
  final Map<String, dynamic> candidate;
  final int index;
  const _CandidateDimCard({required this.candidate, required this.index});

  @override
  Widget build(BuildContext context) {
    final ticker = candidate['ticker']             as String;
    final sector = candidate['sector']             as String? ?? '–';
    final price  = candidate['price_eur']          as num?;
    final perf4w = candidate['performance_4w_pct'] as num?;

    return Opacity(
      opacity: 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: KestrelColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KestrelColors.cardBorder),
        ),
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ticker,
                    style: const TextStyle(color: KestrelColors.textPrimary,
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${price != null ? fmtPrice(price) : '–'} · $sector',
                    style: const TextStyle(color: KestrelColors.textGrey, fontSize: 10)),
              ]),
            ),
            if (perf4w != null)
              Text(fmtPct(perf4w),
                  style: TextStyle(
                      color: perf4w >= 0 ? KestrelColors.green : KestrelColors.red,
                      fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Claude Box ────────────────────────────────────────────────

class _ClaudeBox extends StatelessWidget {
  final Map<String, dynamic> claude;
  const _ClaudeBox({required this.claude});

  @override
  Widget build(BuildContext context) {
    final verdict = claude['verdict'] as String? ?? '';
    final summary = claude['summary'] as String? ?? '';
    final isPos   = verdict.toLowerCase() == 'positive';

    return Container(
      decoration: BoxDecoration(
        color: KestrelColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KestrelColors.cardBorder),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isPos ? KestrelColors.greenBg : KestrelColors.redBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: isPos ? KestrelColors.greenBorder : KestrelColors.redBorder),
            ),
            child: Text('Claude · ${verdict.toUpperCase()}',
                style: TextStyle(
                    color: isPos ? KestrelColors.green : KestrelColors.red,
                    fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ]),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(summary,
              style: const TextStyle(color: KestrelColors.textGrey,
                  fontSize: 11, height: 1.4)),
        ],
      ]),
    );
  }
}

// ── Trade Params Row ──────────────────────────────────────────

class _TradeParamsRow extends StatelessWidget {
  final Map<String, dynamic> params;
  const _TradeParamsRow({required this.params});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MetricCell(
            value: params['entry_price_eur'] != null
                ? fmtPrice(params['entry_price_eur'] as num) : '–',
            label: 'Entry')),
        const SizedBox(width: 6),
        Expanded(child: _MetricCell(
            value: params['stop_level_eur'] != null
                ? fmtPrice(params['stop_level_eur'] as num) : '–',
            label: 'Stop')),
        const SizedBox(width: 6),
        Expanded(child: _MetricCell(
            value: '${params['quantity'] ?? '–'}', label: 'Stück')),
      ],
    );
  }
}

// ── Metric Cell ───────────────────────────────────────────────

class _MetricCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  const _MetricCell({required this.value, required this.label, this.valueColor});

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

// ── Footer ────────────────────────────────────────────────────

class _ShortlistFooter extends StatelessWidget {
  final String runTime;
  final Map<String, dynamic> data;
  const _ShortlistFooter({required this.runTime, required this.data});

  @override
  Widget build(BuildContext context) {
    final candidates = data['candidates'] as List;
    final hasClaude  = candidates.any(
            (c) => (c as Map<String, dynamic>)['claude'] != null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Run $runTime',
              style: const TextStyle(color: KestrelColors.textHint, fontSize: 10)),
          if (hasClaude)
            const Text('Claude-Check ✓',
                style: TextStyle(color: KestrelColors.gold, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────

enum _EmptyVariant { pending, budget, none }

class _ShortlistEmptyState extends StatelessWidget {
  final _EmptyVariant variant;
  final String? subText;
  final String? runTime;
  const _ShortlistEmptyState({required this.variant, this.subText, this.runTime});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;

    final svgAsset = switch (variant) {
      _EmptyVariant.pending => 'assets/images/kestrel_pending.svg',
      _EmptyVariant.budget  => 'assets/images/kestrel_no_budget.svg',
      _EmptyVariant.none    => 'assets/images/kestrel_falcon.svg',
    };

    final headline = switch (variant) {
      _EmptyVariant.pending => 'SCAN AUSSTEHEND',
      _EmptyVariant.budget  => 'NEST IST LEER',
      _EmptyVariant.none    => 'HORIZONT LEER',
    };

    final subline = switch (variant) {
      _EmptyVariant.pending => 'Kestrel positioniert sich',
      _EmptyVariant.budget  => 'Kein Budget verfügbar',
      _EmptyVariant.none    => 'Keine Kandidaten',
    };

    final description = switch (variant) {
      _EmptyVariant.pending => 'Warten auf das zeitgesteuerte Signal.\n(Run ca. 15:00 Uhr)',
      _EmptyVariant.budget  => 'Budget liegt unter der Mindestposition.\nPrüfe deine Liquidität.',
      _EmptyVariant.none    => 'Weit und breit keine Beute.\nMarkt bietet gerade keine Signale.',
    };

    return SizedBox(
      height: screenH * 0.75,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Sonnenstrahlen ganz hinten
              // Sonnenstrahlen nur bei pending
              if (variant == _EmptyVariant.pending)
                CustomPaint(
                  size: Size(screenW * 0.72, screenW * 0.72),
                  painter: _SunRaysPainter(),
                ),
              // Kreisrahmen
              Container(
                width: screenW * 0.72,
                height: screenW * 0.72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: KestrelColors.gold.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
              ),
              // Falke vorne
              SvgPicture.asset(
                svgAsset,
                width: screenW * 0.60,
                colorFilter: const ColorFilter.mode(
                  KestrelColors.gold,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            headline,
            style: const TextStyle(
              color: KestrelColors.goldLight,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subline,
            style: const TextStyle(
              color: KestrelColors.textGrey,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              description,
              style: const TextStyle(
                color: KestrelColors.textDimmed,
                fontSize: 12,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (runTime != null) ...[
            const SizedBox(height: 16),
            Text(
              'Letzter Run: $runTime',
              style: const TextStyle(
                color: KestrelColors.textHint,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sun Rays Painter ──────────────────────────────────────────

class _SunRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.6, size.height * 0.47);
    const rayCount = 12;
    // Strahlen fächern nach oben: von -150° bis -30° (oben = -90°)
    const startAngle = -170.0;
    const sweepAngle = 160.0;

    for (int i = 0; i < rayCount; i++) {
      final fraction = i / (rayCount - 1);
      final angleDeg = startAngle + fraction * sweepAngle;
      final angleRad = angleDeg * math.pi / 180.0;

      // Mittlere Strahlen länger und heller
      final centerFraction = 1.0 - (fraction - 0.5).abs() * 2;
      final rayLength = size.height * (0.28 + centerFraction * 0.22);

      final endX = origin.dx + math.cos(angleRad) * rayLength;
      final endY = origin.dy + math.sin(angleRad) * rayLength;

      // Strahl als Dreieck (breit am Ende, Punkt am Ursprung)
      final perpAngle = angleRad + math.pi / 2;
      final spreadWidth = rayLength * 0.08;
      final end1 = Offset(
        endX + math.cos(perpAngle) * spreadWidth,
        endY + math.sin(perpAngle) * spreadWidth,
      );
      final end2 = Offset(
        endX - math.cos(perpAngle) * spreadWidth,
        endY - math.sin(perpAngle) * spreadWidth,
      );

      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(end1.dx, end1.dy)
        ..lineTo(end2.dx, end2.dy)
        ..close();

      final paint = Paint()
        ..shader = ui.Gradient.linear(
          origin,
          Offset(endX, endY),
          [
            const Color(0xFFC9A84C).withOpacity(0.18 + centerFraction * 0.12),
            const Color(0xFFC9A84C).withOpacity(0.0),
          ],
        )
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);
    }

    // Kleiner Leuchtpunkt am Ursprung
    final glowPaint = Paint()
      ..color = const Color(0xFFC9A84C).withOpacity(0.20)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(origin, 6, glowPaint);
    canvas.drawCircle(origin, 3,
        Paint()..color = const Color(0xFFC9A84C).withOpacity(0.50)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_SunRaysPainter old) => false;
}