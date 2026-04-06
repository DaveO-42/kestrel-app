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
      });
    } catch (e) {
      setState(() {
        _error   = e.toString();
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

    final status     = _data!['status']       as String;
    final runId      = _data!['run_id']        as String;
    final candidates = _data!['candidates']    as List;
    final topCandidate = _data!['top_candidate'];
    final topTicker  = topCandidate != null
        ? (topCandidate as Map<String, dynamic>)['ticker'] as String?
        : null;

    final runTime = runId.length >= 13
        ? '${runId.substring(9, 11)}:${runId.substring(11, 13)}'
        : runId;

    final paused = _system?['paused'] as bool? ?? false;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: _buildAppBar(status),
      body: Column(
        children: [
          if (paused) PauseBanner(
            drawdownPct: _system?['drawdown_pct'] as num?,
            reason: _system?['pause_reason'] as String?,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: KestrelColors.gold,
              backgroundColor: KestrelColors.cardBg,
              child: candidates.isEmpty
                  ? _buildEmpty(status)
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
          const Text('Shortlist',
              style: TextStyle(
                  color: KestrelColors.goldLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
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

  Widget _buildEmpty(String status) {
    final message = switch (status) {
      'confirmed' => 'Shortlist bereits bestätigt',
      'skipped'   => 'Alle Kandidaten übersprungen',
      'expired'   => 'Shortlist abgelaufen – kein Run heute',
      _           => 'Keine Kandidaten verfügbar',
    };
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              const Icon(Icons.list_alt_outlined,
                  color: KestrelColors.textHint, size: 48),
              const SizedBox(height: 16),
              Text(message,
                  style: const TextStyle(
                      color: KestrelColors.textDimmed, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color bg;
    final Color border;
    final String label;

    switch (status) {
      case 'pending':
        label = 'heute · pending';
        color = KestrelColors.gold;
        bg    = KestrelColors.goldBg;
        border= KestrelColors.goldBorder;
      case 'confirmed':
        label = 'bestätigt';
        color = KestrelColors.green;
        bg    = KestrelColors.greenBg;
        border= KestrelColors.greenBorder;
      case 'expired':
        label = 'abgelaufen';
        color = KestrelColors.red;
        bg    = KestrelColors.redBg;
        border= KestrelColors.redBorder;
      default:
        label = status;
        color = KestrelColors.textDimmed;
        bg    = KestrelColors.screenBg;
        border= KestrelColors.cardBorder;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Kandidaten-Card (Top) ─────────────────────────────────────

class _CandidateCard extends StatelessWidget {
  final Map<String, dynamic> candidate;
  const _CandidateCard({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final ticker  = candidate['ticker']              as String;
    final sector  = candidate['sector']              as String?  ?? '–';
    final score   = candidate['score']               as num?;
    final price   = candidate['price_eur']           as num?;
    final perf4w  = candidate['performance_4w_pct']  as num?;
    final rsi     = candidate['rsi']                 as num?;
    final claude  = candidate['claude']              as Map<String, dynamic>?;
    final params  = candidate['trade_params']        as Map<String, dynamic>?;

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

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ticker,
                          style: const TextStyle(
                              color: KestrelColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(sector,
                          style: const TextStyle(
                              color: KestrelColors.textGrey, fontSize: 10)),
                    ],
                  ),
                  if (score != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 4),
                      decoration: BoxDecoration(
                        color: KestrelColors.goldBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: KestrelColors.goldBorder),
                      ),
                      child: Text(
                        score.toStringAsFixed(1).replaceAll('.', ','),
                        style: const TextStyle(
                            color: KestrelColors.goldLight,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),

            // Metriken
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top:    BorderSide(color: KestrelColors.cardBorder),
                  bottom: BorderSide(color: KestrelColors.cardBorder),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 13),
              child: Row(
                children: [
                  Expanded(child: _MetricCell(
                    value: fmtPct(perf4w, showSign: true),
                    label: '4W Perf.',
                    valueColor: (perf4w ?? 0) >= 0
                        ? KestrelColors.green : KestrelColors.red,
                  )),
                  Expanded(child: _MetricCell(
                    value: fmtPrice(price),
                    label: 'Kurs',
                  )),
                  Expanded(child: _MetricCell(
                    value: rsi != null
                        ? rsi.toStringAsFixed(1).replaceAll('.', ',')
                        : '–',
                    label: 'RSI',
                  )),
                ],
              ),
            ),

            // Claude-Box
            if (claude != null) ...[
              _ClaudeBox(claude: claude),
              const SizedBox(height: 10),
            ],

            // Trade-Params
            if (params != null)
              _TradeParamsStrip(params: params),
          ],
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  const _MetricCell({required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: valueColor ?? KestrelColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: KestrelColors.textGrey, fontSize: 9)),
      ],
    );
  }
}

// ── Claude Box ────────────────────────────────────────────────

class _ClaudeBox extends StatelessWidget {
  final Map<String, dynamic> claude;
  const _ClaudeBox({required this.claude});

  @override
  Widget build(BuildContext context) {
    final einschaetzung = claude['katalysator_eingeschaetzt'] as String? ?? '';
    final gegenargs     = claude['gegenargumente']            as List?   ?? [];
    final gapRisiko     = claude['gap_risiko']                as String? ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 2, color: KestrelColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CLAUDE',
                      style: TextStyle(
                          color: KestrelColors.gold,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6)),
                  const SizedBox(height: 4),
                  if (einschaetzung.isNotEmpty)
                    Text(einschaetzung,
                        style: const TextStyle(
                            color: KestrelColors.textGrey,
                            fontSize: 11,
                            height: 1.4)),
                  if (gegenargs.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '⚠ ${gegenargs.join(' · ')}',
                      style: const TextStyle(
                          color: KestrelColors.orange,
                          fontSize: 10,
                          height: 1.4),
                    ),
                  ],
                  if (gapRisiko.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text('Gap-Risiko: $gapRisiko',
                        style: const TextStyle(
                            color: KestrelColors.textDimmed, fontSize: 10)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trade Params Strip ────────────────────────────────────────

class _TradeParamsStrip extends StatelessWidget {
  final Map<String, dynamic> params;
  const _TradeParamsStrip({required this.params});

  @override
  Widget build(BuildContext context) {
    final entry    = params['entry_price_eur'] as num?;
    final stop     = params['stop_level_eur']  as num?;
    final qty      = params['quantity']        as num?;
    final position = params['position_eur']    as num?;
    final risk     = params['total_risk_eur']  as num?;

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KestrelColors.cardBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ParamMini(value: fmtPrice(entry),    label: 'Entry'),
          _ParamMini(value: fmtPrice(stop),     label: 'Stop'),
          _ParamMini(
            value: qty != null ? '${qty.toInt()} Stk.' : '–',
            label: 'Menge',
          ),
          _ParamMini(value: fmtPrice(position), label: 'Position'),
          _ParamMini(value: fmtPrice(risk),     label: 'Risiko'),
        ],
      ),
    );
  }
}

class _ParamMini extends StatelessWidget {
  final String value;
  final String label;
  const _ParamMini({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: KestrelColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: KestrelColors.textGrey, fontSize: 9)),
      ],
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
    final score  = candidate['score']  as num?;
    final sector = candidate['sector'] as String? ?? '–';

    return Opacity(
      opacity: 0.45,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141E2C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: KestrelColors.cardBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticker,
                    style: const TextStyle(
                        color: KestrelColors.textDimmed,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Score ${score?.toStringAsFixed(1).replaceAll('.', ',') ?? '–'} · $sector',
                  style: const TextStyle(
                      color: KestrelColors.textGrey, fontSize: 10),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: KestrelColors.screenBg,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: KestrelColors.cardBorder),
              ),
              child: Text('Kandidat $index',
                  style: const TextStyle(
                      color: KestrelColors.textHint, fontSize: 10)),
            ),
          ],
        ),
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
              style: const TextStyle(
                  color: KestrelColors.textHint, fontSize: 10)),
          if (hasClaude)
            const Text('Claude-Check ✓',
                style: TextStyle(color: KestrelColors.gold, fontSize: 10)),
        ],
      ),
    );
  }
}