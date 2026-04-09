import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';
import '../../widgets/info_sheet.dart';
import '../../widgets/offline_banner.dart';

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
      final results = await Future.wait([
        ApiService.getShortlist(),
        ApiService.getSystemStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _dataResult   = results[0] as CachedResult<Map<String, dynamic>>;
        _systemResult = results[1] as CachedResult<Map<String, dynamic>>;
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
    final candidates   = data['candidates']     as List? ?? [];
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
                          ? _CandidateCard(candidate: candidate)
                          : _CandidateDimCard(
                        candidate: candidate,
                        index: entry.key + 1,
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
          child: _ShortlistEmptyCard(
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

// ── Empty State ───────────────────────────────────────────────

enum _EmptyVariant { pending, budget, none }

class _ShortlistEmptyCard extends StatelessWidget {
  final _EmptyVariant variant;
  final String? subText;
  final String? runTime;
  const _ShortlistEmptyCard({required this.variant, this.subText, this.runTime});

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
          Text('SHORTLIST', style: kCardLabelStyle),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 32, height: 32,
                    child: CustomPaint(
                      painter: switch (variant) {
                        _EmptyVariant.pending => _ClockIconPainter(),
                        _EmptyVariant.budget  => _LockIconPainter(),
                        _EmptyVariant.none    => _SearchIconPainter(),
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    switch (variant) {
                      _EmptyVariant.pending => 'Run steht noch aus',
                      _EmptyVariant.budget  => 'Kein Budget verfügbar',
                      _EmptyVariant.none    => 'Keine Kandidaten',
                    },
                    style: TextStyle(
                      color: switch (variant) {
                        _EmptyVariant.budget => KestrelColors.gold,
                        _                   => const Color(0xFF6A8AAA),
                      },
                      fontSize: 12, fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subText != null) ...[
                    const SizedBox(height: 4),
                    Text(subText!,
                        style: const TextStyle(
                            color: Color(0xFF8a6e2a), fontSize: 10),
                        textAlign: TextAlign.center),
                  ],
                  if (runTime != null) ...[
                    const SizedBox(height: 4),
                    Text('Run $runTime',
                        style: const TextStyle(
                            color: Color(0xFF334d68), fontSize: 10)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Icon Painters (unverändert) ───────────────────────────────

class _ClockIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF334d68)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1;
    canvas.drawCircle(c, r, p);
    canvas.drawLine(c, Offset(c.dx, c.dy - r * 0.55), p);
    canvas.drawLine(c, Offset(c.dx + r * 0.4, c.dy), p);
  }
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

class _LockIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFc9a84c)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width; final h = size.height;
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.45, w * 0.6, h * 0.45),
        const Radius.circular(3));
    canvas.drawRRect(rrect, p);
    final arcPaint = Paint()
      ..color = const Color(0xFFc9a84c)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
        Rect.fromLTWH(w * 0.28, h * 0.1, w * 0.44, h * 0.45),
        3.14, 3.14, false, arcPaint);
    final dotPaint = Paint()..color = const Color(0xFFc9a84c);
    canvas.drawCircle(Offset(w / 2, h * 0.68), 2, dotPaint);
  }
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

class _SearchIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF6a8aaa)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width; final h = size.height;
    canvas.drawCircle(Offset(w * 0.44, h * 0.44), w * 0.28, p);
    canvas.drawLine(
        Offset(w * 0.64, h * 0.64), Offset(w * 0.84, h * 0.84), p);
    final xp = Paint()
      ..color = const Color(0xFFe84040)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.32, h * 0.32), Offset(w * 0.56, h * 0.56), xp);
    canvas.drawLine(Offset(w * 0.56, h * 0.32), Offset(w * 0.32, h * 0.56), xp);
  }
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

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

class _CandidateCard extends StatelessWidget {
  final Map<String, dynamic> candidate;
  const _CandidateCard({required this.candidate});

  @override
  Widget build(BuildContext context) {
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
          if (claude != null) ...[
            const SizedBox(height: 10),
            _ClaudeBox(claude: claude),
          ],
          if (params != null) ...[
            const SizedBox(height: 10),
            _TradeParamsRow(params: params),
          ],
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
            value: params['entry_price'] != null
                ? fmtPrice(params['entry_price'] as num) : '–',
            label: 'Entry')),
        const SizedBox(width: 6),
        Expanded(child: _MetricCell(
            value: params['stop_price'] != null
                ? fmtPrice(params['stop_price'] as num) : '–',
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