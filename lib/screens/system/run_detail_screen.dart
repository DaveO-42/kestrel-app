import 'package:flutter/material.dart';
import '../../theme/kestrel_theme.dart';

class RunDetailScreen extends StatelessWidget {
  final Map<String, dynamic> run;
  const RunDetailScreen({super.key, required this.run});

  // '20260413_150012' → '13.04.2026'
  String _fmtDate(String? runId) {
    if (runId == null || runId.length < 8) return '–';
    final year  = runId.substring(0, 4);
    final month = runId.substring(4, 6);
    final day   = runId.substring(6, 8);
    return '$day.$month.$year';
  }

  // ISO → 'HH:mm' (Ortszeit)
  String _fmtTime(String? iso) {
    if (iso == null) return '–';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '–';
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  // Laufzeit in ganzen Minuten
  int _runtimeMin(String? start, String? end) {
    if (start == null || end == null) return 0;
    final s = DateTime.tryParse(start);
    final e = DateTime.tryParse(end);
    if (s == null || e == null) return 0;
    return e.difference(s).inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final runId     = run['run_id']        as String? ?? '';
    final status    = run['order_status']  as String? ?? 'skipped';
    final ticker    = run['order_ticker']  as String?;
    final startedAt = run['started_at']    as String?;
    final doneAt    = run['completed_at']  as String?;
    final shortlist = run['shortlist']     as List? ?? [];
    final kauf      = run['kaufentscheidung'] as Map<String, dynamic>?;

    final isFilled  = status == 'filled' || status == 'bought';
    final topTicker = kauf?['ticker'] as String?;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: AppBar(
        backgroundColor: KestrelColors.appBarBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: KestrelColors.textDimmed, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            KestrelLogo(size: 22),
            const SizedBox(width: 8),
            const Text(
              'Run Detail',
              style: TextStyle(
                color: KestrelColors.goldLight,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: KestrelColors.cardBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [

          // ── 1. Hero Card ──────────────────────────────────────
          GoldTopCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Run $runId',
                              style: const TextStyle(
                                  color: KestrelColors.textGrey,
                                  fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(_fmtDate(runId),
                              style: const TextStyle(
                                  color: KestrelColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      _StatusBadge(status: status),
                    ],
                  ),
                  if (isFilled && ticker != null) ...[
                    const SizedBox(height: 10),
                    Text('Order: $ticker gekauft',
                        style: const TextStyle(
                            color: KestrelColors.green, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── 2. Timing Card ────────────────────────────────────
          _Card(
            label: 'TIMING',
            child: Row(children: [
              Expanded(child: _StatCell(
                  value: _fmtTime(startedAt), label: 'Start')),
              const SizedBox(width: 6),
              Expanded(child: _StatCell(
                  value: _fmtTime(doneAt), label: 'Ende')),
              const SizedBox(width: 6),
              Expanded(child: _StatCell(
                  value: '${_runtimeMin(startedAt, doneAt)} min',
                  label: 'Laufzeit')),
            ]),
          ),
          const SizedBox(height: 8),

          // ── 3. Shortlist Card ─────────────────────────────────
          _Card(
            label: 'SHORTLIST (${shortlist.length} '
                '${shortlist.length == 1 ? 'Kandidat' : 'Kandidaten'})',
            child: shortlist.isEmpty
                ? const Text('Keine Kandidaten in diesem Run',
                    style: TextStyle(
                        color: KestrelColors.textGrey, fontSize: 11))
                : Column(
                    children: shortlist.asMap().entries.map((entry) {
                      final isLast      = entry.key == shortlist.length - 1;
                      final c           = entry.value as Map<String, dynamic>;
                      final cTicker     = c['ticker']            as String? ?? '–';
                      final score       = (c['score']            as num?)?.toDouble();
                      final eps         = c['eps_surprise_pct']  as num?;
                      final perf4w      = c['performance_4w']    as num?;
                      final rsi         = (c['rsi']              as num?)?.toInt();
                      final isTop       = topTicker != null && cTicker == topTicker;

                      final epsStr  = eps   != null ? '${eps >= 0 ? '+' : ''}${eps.toStringAsFixed(1)}%'   : '–';
                      final perfStr = perf4w != null ? '${perf4w >= 0 ? '+' : ''}${perf4w.toStringAsFixed(1)}%' : '–';
                      final rsiStr  = rsi   != null ? '$rsi' : '–';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(cTicker,
                                            style: const TextStyle(
                                                color: KestrelColors.textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700)),
                                        if (isTop) ...[
                                          const SizedBox(width: 5),
                                          _TopBadge(),
                                        ],
                                      ]),
                                      const SizedBox(height: 3),
                                      Text(
                                        'EPS $epsStr  |  4W $perfStr  |  RSI $rsiStr',
                                        style: const TextStyle(
                                            color: KestrelColors.textGrey,
                                            fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  score != null
                                      ? score.toStringAsFixed(2)
                                      : '–',
                                  style: const TextStyle(
                                      color: KestrelColors.gold,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            const Divider(
                                height: 1,
                                thickness: 1,
                                color: KestrelColors.cardBorder),
                        ],
                      );
                    }).toList(),
                  ),
          ),

          // ── 4. Kaufentscheidung Card (nur filled) ─────────────
          if (isFilled && kauf != null) ...[
            const SizedBox(height: 8),
            _Card(
              label: 'KAUFENTSCHEIDUNG',
              child: Column(
                children: [
                  _KvRow('Ticker',  kauf['ticker']        as String? ?? '–'),
                  const Divider(height: 1, thickness: 1, color: KestrelColors.cardBorder),
                  _KvRow('Kurs',    fmtPrice(kauf['price_eur']       as num?)),
                  const Divider(height: 1, thickness: 1, color: KestrelColors.cardBorder),
                  _KvRow('Stück',   '${(kauf['quantity'] as num?)?.toInt() ?? '–'}'),
                  const Divider(height: 1, thickness: 1, color: KestrelColors.cardBorder),
                  _KvRow('Stop',    fmtPrice(kauf['stop_eur']        as num?)),
                  const Divider(height: 1, thickness: 1, color: KestrelColors.cardBorder),
                  _KvRow('Risiko',  fmtPrice(kauf['total_risk_eur']  as num?)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String label;
  final Widget child;
  const _Card({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: kCardDecoration(),
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

// ── Stat Cell ─────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: kInnerCellDecoration(),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Column(children: [
        Text(value,
            style: const TextStyle(
                color: KestrelColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: KestrelColors.textGrey, fontSize: 9)),
      ]),
    );
  }
}

// ── Key-Value Row ─────────────────────────────────────────────

class _KvRow extends StatelessWidget {
  final String label;
  final String value;
  const _KvRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: KestrelColors.textGrey, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: KestrelColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Order-Status Badge ────────────────────────────────────────

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
      case 'filled':
      case 'bought':
        label  = 'gekauft';
        color  = KestrelColors.green;
        bg     = KestrelColors.greenBg;
        border = KestrelColors.greenBorder;
      case 'pending':
        label  = 'pending';
        color  = KestrelColors.gold;
        bg     = KestrelColors.goldBg;
        border = KestrelColors.goldBorder;
      default:
        label  = 'skipped';
        color  = KestrelColors.textGrey;
        bg     = KestrelColors.grayBg;
        border = KestrelColors.grayBorder;
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
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
    );
  }
}

// ── TOP Badge ─────────────────────────────────────────────────

class _TopBadge extends StatelessWidget {
  const _TopBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: KestrelColors.goldBg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: KestrelColors.goldBorder),
      ),
      child: const Text(
        'TOP',
        style: TextStyle(
          color: KestrelColors.gold,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
