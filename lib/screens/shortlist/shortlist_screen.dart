import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';

class ShortlistScreen extends StatefulWidget {
  const ShortlistScreen({super.key});

  @override
  State<ShortlistScreen> createState() => _ShortlistScreenState();
}

class _ShortlistScreenState extends State<ShortlistScreen> {
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _system;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getShortlist(),
        ApiService.getSystemStatus(),
      ]);
      setState(() {
        _data    = results[0] as Map<String, dynamic>;
        _system  = results[1] as Map<String, dynamic>;
        _loading = false;
        _error   = null;
      });
      if (!ApiService.useMock) KestrelNav.of(context)?.setConnectionError(false);
    } catch (e) {
      setState(() {
        _error   = e.toString();
        _loading = false;
      });
      if (!ApiService.useMock) KestrelNav.of(context)?.setConnectionError(true);
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
    final connError = KestrelNav.of(context)?.connectionError ?? false;

    final status       = _data!['status']        as String? ?? 'pending';
    final runId        = _data!['run_id']         as String? ?? '';
    final candidates   = _data!['candidates']     as List? ?? [];
    final topCandidate = _data!['top_candidate'];
    final topTicker    = topCandidate != null
        ? (topCandidate as Map<String, dynamic>)['ticker'] as String?
        : null;

    final runTime = runId.length >= 13
        ? '${runId.substring(9, 11)}:${runId.substring(11, 13)}'
        : runId;

    final paused = _system?['is_paused'] as bool? ?? false;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: _buildAppBar(status),
      body: Column(
        children: [
          if (paused)
            PauseBanner(
              drawdownPct: _system?['drawdown_pct'] as num?,
              reason: _system?['pause_reason'] as String?,
            ),
          if (connError) const ErrorBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: KestrelColors.gold,
              backgroundColor: KestrelColors.cardBg,
              child: candidates.isEmpty
                  ? _buildEmpty(status, runId)
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
                  _ShortlistFooter(runTime: runTime, data: _data!),
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
          const Text(
            'Shortlist',
            style: TextStyle(
              color: KestrelColors.goldLight,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _StatusBadge(status: status),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: KestrelColors.cardBorder),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────

  Widget _buildEmpty(String status, String runId) {
    final reason  = _data!['order_reason'] as String?;
    final runDate = _data!['run_date']     as String?;

    final runTime = runId.length >= 13
        ? '${runId.substring(9, 11)}:${runId.substring(11, 13)}'
        : null;

    // Zustand bestimmen
    final isBudget  = reason != null &&
        reason.toLowerCase().contains('budget');
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

// ── Empty State Enum ──────────────────────────────────────────

enum _EmptyVariant { pending, budget, none }

// ── Empty State Card ──────────────────────────────────────────

class _ShortlistEmptyCard extends StatelessWidget {
  final _EmptyVariant variant;
  final String? subText;
  final String? runTime;

  const _ShortlistEmptyCard({
    required this.variant,
    this.subText,
    this.runTime,
  });

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
                    width: 32,
                    height: 32,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subText!,
                      style: TextStyle(
                        color: switch (variant) {
                          _EmptyVariant.budget => const Color(0xFF8A6E2A),
                          _                   => const Color(0xFF334D68),
                        },
                        fontSize: 10,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (runTime != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Run $runTime',
                      style: const TextStyle(
                        color: Color(0xFF334D68),
                        fontSize: 10,
                      ),
                    ),
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

// ── Icon Painters ─────────────────────────────────────────────

class _ClockIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF334D68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.34;
    canvas.drawCircle(c, r, p);
    canvas.drawLine(c, c + Offset(0, -r * 0.6), p);
    canvas.drawLine(c, c + Offset(r * 0.5, 0), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _LockIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = KestrelColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Körper
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.25, h * 0.4375, w * 0.5, h * 0.375),
        const Radius.circular(2),
      ),
      p,
    );
    // Bügel
    final arc = Path()
      ..moveTo(w * 0.34, h * 0.4375)
      ..lineTo(w * 0.34, h * 0.25)
      ..arcToPoint(
        Offset(w * 0.66, h * 0.25),
        radius: Radius.circular(w * 0.16),
        clockwise: false,
      )
      ..lineTo(w * 0.66, h * 0.4375);
    canvas.drawPath(arc, p);
    // Schlüsselloch-Punkt
    canvas.drawCircle(
      Offset(w / 2, h * 0.5625),
      w * 0.05,
      Paint()
        ..color = KestrelColors.gold
        ..style = PaintingStyle.fill,
    );
    // Strich nach unten
    p.strokeWidth = 1.3;
    canvas.drawLine(
      Offset(w / 2, h * 0.6125),
      Offset(w / 2, h * 0.6875),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _SearchIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF6A8AAA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    canvas.drawCircle(Offset(w * 0.44, h * 0.44), w * 0.27, p);
    canvas.drawLine(
      Offset(w * 0.64, h * 0.64),
      Offset(w * 0.84, h * 0.84),
      p,
    );
    // X im Kreis
    final pX = Paint()
      ..color = const Color(0xFFE84040)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.32, h * 0.32),
      Offset(w * 0.56, h * 0.56),
      pX,
    );
    canvas.drawLine(
      Offset(w * 0.56, h * 0.32),
      Offset(w * 0.32, h * 0.56),
      pX,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Status Badge ──────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg, border) = switch (status) {
      'pending'   => ('heute · pending',  KestrelColors.gold,        KestrelColors.goldBg,   KestrelColors.goldBorder),
      'confirmed' => ('bestätigt',        KestrelColors.green,       KestrelColors.greenBg,  KestrelColors.greenBorder),
      'skipped'   => ('übersprungen',     KestrelColors.textDimmed,  KestrelColors.screenBg, KestrelColors.cardBorder),
      'expired'   => ('abgelaufen',       KestrelColors.red,         KestrelColors.redBg,    KestrelColors.redBorder),
      _           => (status,             KestrelColors.textDimmed,  KestrelColors.screenBg, KestrelColors.cardBorder),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
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
        border: Border(
          top: BorderSide(color: KestrelColors.gold, width: 2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticker,
                    style: const TextStyle(
                      color: KestrelColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    sector,
                    style: const TextStyle(
                      color: KestrelColors.textGrey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: KestrelColors.goldBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: KestrelColors.goldBorder),
                  ),
                  child: Text(
                    'Score ${score.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: KestrelColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Metriken
          Row(
            children: [
              Expanded(
                child: _MetricCell(
                  value: price != null ? fmtPrice(price) : '–',
                  label: 'Kurs',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MetricCell(
                  value: perf4w != null ? fmtPct(perf4w) : '–',
                  label: '4W-Perf',
                  valueColor: perf4w != null && perf4w >= 0
                      ? KestrelColors.green
                      : KestrelColors.red,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MetricCell(
                  value: rsi != null ? rsi.toStringAsFixed(1) : '–',
                  label: 'RSI',
                ),
              ),
            ],
          ),
          // Claude-Box
          if (claude != null) ...[
            const SizedBox(height: 10),
            _ClaudeBox(claude: claude),
          ],
          // Trade-Parameter
          if (params != null) ...[
            const SizedBox(height: 10),
            _TradeParamsRow(params: params),
          ],
        ],
      ),
    );
  }
}

// ── Dim Card (weitere Kandidaten) ─────────────────────────────

class _CandidateDimCard extends StatelessWidget {
  final Map<String, dynamic> candidate;
  final int index;
  const _CandidateDimCard({required this.candidate, required this.index});

  @override
  Widget build(BuildContext context) {
    final ticker = candidate['ticker'] as String;
    final sector = candidate['sector'] as String? ?? '–';
    final score  = candidate['score']  as num?;
    final price  = candidate['price_eur'] as num?;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticker,
                    style: const TextStyle(
                      color: KestrelColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${price != null ? fmtPrice(price) : '–'} · $sector',
                    style: const TextStyle(
                      color: KestrelColors.textGrey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (perf4w != null)
                  Text(
                    fmtPct(perf4w),
                    style: TextStyle(
                      color: perf4w >= 0 ? KestrelColors.green : KestrelColors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: KestrelColors.screenBg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: KestrelColors.cardBorder),
                  ),
                  child: Text(
                    'Kandidat $index',
                    style: const TextStyle(
                      color: KestrelColors.textHint,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Claude-Box ────────────────────────────────────────────────

class _ClaudeBox extends StatelessWidget {
  final Map<String, dynamic> claude;
  const _ClaudeBox({required this.claude});

  @override
  Widget build(BuildContext context) {
    final intakt  = claude['katalysator_intakt']       as bool?;
    final einsch  = claude['katalysator_eingeschaetzt'] as String?;
    final gegenargumente = claude['gegenargumente'] as List? ?? [];
    final gapRisk = claude['gap_risiko'] as String?;
    final gapText = claude['gap_risiko_begruendung'] as String?;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: KestrelColors.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Claude',
                      style: TextStyle(
                        color: KestrelColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (intakt != null)
                      Text(
                        intakt ? 'Katalysator intakt' : 'Katalysator fraglich',
                        style: TextStyle(
                          color: intakt ? KestrelColors.green : KestrelColors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (einsch != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    einsch,
                    style: const TextStyle(
                      color: KestrelColors.textGrey,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
                if (gegenargumente.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '⚠ ${(gegenargumente as List<dynamic>).join(' · ')}',
                    style: const TextStyle(
                      color: KestrelColors.orange,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
                if (gapRisk != null && gapRisk != 'niedrig' && gapText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Gap-Risiko: $gapText',
                    style: const TextStyle(
                      color: KestrelColors.red,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
        Expanded(
          child: _MetricCell(
            value: fmtPrice(params["entry_price_eur"] as num?),
            label: 'Entry',
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _MetricCell(
            value: fmtPrice(params["stop_level_eur"] as num?),
            label: 'Stop',
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _MetricCell(
            value: '${params['quantity'] ?? '–'}',
            label: 'Stück',
          ),
        ),
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
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? KestrelColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: KestrelColors.textGrey,
              fontSize: 9,
            ),
          ),
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
          (c) => (c as Map<String, dynamic>)['claude'] != null,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Run $runTime',
            style: const TextStyle(
              color: KestrelColors.textHint,
              fontSize: 10,
            ),
          ),
          if (hasClaude)
            const Text(
              'Claude-Check ✓',
              style: TextStyle(
                color: KestrelColors.gold,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}