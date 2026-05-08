import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/kestrel_theme.dart';

class PaperTab extends StatefulWidget {
  const PaperTab({super.key});

  @override
  State<PaperTab> createState() => _PaperTabState();
}

class _PaperTabState extends State<PaperTab> {
  Map<String, dynamic>? _summary;
  List<dynamic>?        _positions;
  List<dynamic>?        _history;
  List<dynamic>?        _runs;
  bool                  _loading = true;
  String?               _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final summary   = await ApiService.getPaperSummary();
      final positions = await ApiService.getPaperPositions();
      final history   = await ApiService.getPaperHistory();
      final runs      = await ApiService.getPaperRuns();
      if (!mounted) return;
      setState(() {
        _summary   = summary;
        _positions = positions;
        _history   = history;
        _runs      = runs;
        _loading   = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: KestrelColors.gold),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(color: KestrelColors.red, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final positions = _positions ?? [];
    final investiertEur = positions.fold<double>(0.0, (sum, p) {
      final pos      = p as Map<String, dynamic>;
      final price    = (pos['entry_price'] as num?)?.toDouble() ?? 0.0;
      final qty      = (pos['quantity']    as num?)?.toDouble() ?? 0.0;
      return sum + price * qty;
    });

    return RefreshIndicator(
      onRefresh: _load,
      color: KestrelColors.gold,
      backgroundColor: KestrelColors.cardBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          _PaperSummaryCard(
            summary: _summary ?? {},
            investiertEur: investiertEur,
          ),
          const SizedBox(height: 8),
          _PaperPositionList(positions: positions),
          const SizedBox(height: 8),
          _PaperHistoryList(history: _history ?? []),
          const SizedBox(height: 8),
          _PaperRunLog(runs: _runs ?? []),
        ],
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────

class _PaperSummaryCard extends StatefulWidget {
  final Map<String, dynamic> summary;
  final double               investiertEur;
  const _PaperSummaryCard({
    required this.summary,
    required this.investiertEur,
  });

  @override
  State<_PaperSummaryCard> createState() => _PaperSummaryCardState();
}

class _PaperSummaryCardState extends State<_PaperSummaryCard> {
  bool _strategyExpanded = false;

  String _fmtBudget(num? budget) {
    if (budget == null) return '€5.000 virtuell';
    final intVal = budget.toInt();
    if (intVal >= 1000) {
      final thousands = intVal ~/ 1000;
      final remainder = intVal % 1000;
      return remainder == 0
          ? '€$thousands.000 virtuell'
          : '€$thousands.${remainder.toString().padLeft(3, '0')} virtuell';
    }
    return '€$intVal virtuell';
  }

  String _fmtInvestiert(double eur) {
    if (eur == 0) return '€0';
    return '€${eur.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final summary       = widget.summary;
    final totalTrades   = (summary['total_trades']   as num?)?.toInt() ?? 0;
    final winRate       = summary['win_rate']         as num?;
    final avgReturn     = summary['avg_return']       as num?;
    final sharpe        = summary['sharpe']           as num?;
    final openPositions = (summary['open_positions'] as num?)?.toInt() ?? 0;

    final budgetStr     = _fmtBudget(summary['virtual_budget'] as num?);
    final investiertStr = _fmtInvestiert(widget.investiertEur);

    return GoldTopCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PAPER TRADING',
                    style: TextStyle(
                        color:         KestrelColors.gold,
                        fontSize:      10,
                        fontWeight:    FontWeight.w700,
                        letterSpacing: 0.8)),
                GestureDetector(
                  onTap: () =>
                      setState(() => _strategyExpanded = !_strategyExpanded),
                  child: Row(
                    children: [
                      Text(
                        'Strategie',
                        style: const TextStyle(
                            color:    KestrelColors.textDimmed,
                            fontSize: 10),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _strategyExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: KestrelColors.textDimmed,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Strategy section (collapsible) ────────────────
            if (_strategyExpanded) ...[
              const SizedBox(height: 10),
              const Text('EARNINGS QUALITY',
                  style: TextStyle(
                      color:         KestrelColors.gold,
                      fontSize:      10,
                      fontWeight:    FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 6),
              _StrategyRow(label: 'Budget',        value: budgetStr),
              _StrategyRow(label: 'Investiert',    value: investiertStr),
              _StrategyRow(label: 'EPS Surprise',  value: '≥ 5 %'),
              _StrategyRow(label: 'Revenue Beat',  value: '≥ 2 %'),
              _StrategyRow(label: 'Gap',           value: '≥ 5 %, kein Fill'),
              _StrategyRow(label: 'Markt-Filter',  value: 'QQQ DD ≤ 15 %'),
              _StrategyRow(label: 'Trailing Stop', value: 'ATR × 2.0'),
              _StrategyRow(label: 'Live seit',     value: '07.05.2026'),
              const SizedBox(height: 8),
              Container(height: 0.5, color: KestrelColors.cardBorder),
            ],

            const SizedBox(height: 10),

            // ── Stats grid ────────────────────────────────────
            if (totalTrades == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text('Noch keine Paper-Trades',
                      style: TextStyle(
                          color: KestrelColors.textGrey, fontSize: 13)),
                ),
              )
            else
              Row(
                children: [
                  Expanded(child: _StatCell(value: '$totalTrades', label: 'Trades')),
                  const SizedBox(width: 6),
                  Expanded(child: _StatCell(
                    value: winRate != null
                        ? '${winRate.toStringAsFixed(1)} %' : '–',
                    label: 'Win-Rate',
                    valueColor: (winRate ?? 0) >= 50
                        ? KestrelColors.green : KestrelColors.red,
                  )),
                  const SizedBox(width: 6),
                  Expanded(child: _StatCell(
                    value: avgReturn != null
                        ? '${avgReturn >= 0 ? '+' : ''}${avgReturn.toStringAsFixed(1)} %'
                        : '–',
                    label: 'Ø Return',
                    valueColor: (avgReturn ?? 0) >= 0
                        ? KestrelColors.green : KestrelColors.red,
                  )),
                  const SizedBox(width: 6),
                  Expanded(child: _StatCell(
                    value: sharpe != null
                        ? sharpe.toStringAsFixed(2) : '–',
                    label: 'Sharpe',
                  )),
                  const SizedBox(width: 6),
                  Expanded(child: _StatCell(
                    value: '$openPositions',
                    label: 'Offen',
                  )),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Strategy Row ──────────────────────────────────────────────

class _StrategyRow extends StatelessWidget {
  final String label;
  final String value;
  const _StrategyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: KestrelColors.textGrey, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: KestrelColors.textPrimary, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Open Positions ────────────────────────────────────────────

class _PaperPositionList extends StatelessWidget {
  final List positions;
  const _PaperPositionList({required this.positions});

  @override
  Widget build(BuildContext context) {
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
          Text('OFFENE POSITIONEN (${positions.length})',
              style: const TextStyle(
                  color: KestrelColors.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 4),
          if (positions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('Keine offenen Paper-Positionen',
                    style: TextStyle(
                        color: KestrelColors.textGrey, fontSize: 12)),
              ),
            )
          else
            ...positions.map(
              (p) => _PaperPositionRow(position: p as Map<String, dynamic>),
            ),
        ],
      ),
    );
  }
}

class _PaperPositionRow extends StatelessWidget {
  final Map<String, dynamic> position;
  const _PaperPositionRow({required this.position});

  @override
  Widget build(BuildContext context) {
    final ticker = position['ticker']      as String? ?? '–';
    final pnlPct = (position['pnl_pct']   as num?)   ?? 0;
    final pnlAbs = (position['pnl_abs_eur'] as num?)  ?? 0;
    final isPos  = pnlPct >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: KestrelColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KestrelColors.cardBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: isPos ? KestrelColors.green : KestrelColors.red,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(8)),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(ticker,
                        style: const TextStyle(
                            color: KestrelColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isPos ? '+' : ''}${pnlPct.toStringAsFixed(2)} %',
                          style: TextStyle(
                              color: isPos
                                  ? KestrelColors.green
                                  : KestrelColors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${isPos ? '+' : ''}${pnlAbs.toStringAsFixed(2)} €',
                          style: const TextStyle(
                              color: KestrelColors.textGrey, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trade History ─────────────────────────────────────────────

class _PaperHistoryList extends StatelessWidget {
  final List history;
  const _PaperHistoryList({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: KestrelColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KestrelColors.cardBorder),
        ),
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text('Keine abgeschlossenen Paper-Trades',
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
          Text('HISTORY (${history.length})',
              style: const TextStyle(
                  color: KestrelColors.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 4),
          ...history.map(
            (t) => _PaperHistoryRow(trade: t as Map<String, dynamic>),
          ),
        ],
      ),
    );
  }
}

class _PaperHistoryRow extends StatelessWidget {
  final Map<String, dynamic> trade;
  const _PaperHistoryRow({required this.trade});

  String _fmtDate(String? iso) {
    if (iso == null || iso.length < 10) return '–';
    final parts = iso.substring(0, 10).split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  Color _badgeColor(String? exitType) => switch (exitType) {
        'K.O.'      => KestrelColors.red,
        'Abschluss' => const Color(0xFF4A7FA5),
        'Technisch' => KestrelColors.orange,
        'Stop'      => KestrelColors.textDimmed,
        _           => KestrelColors.textDimmed,
      };

  @override
  Widget build(BuildContext context) {
    final pnl      = trade['pnl_abs_eur'] as num?;
    final pnlPct   = trade['pnl_pct']     as num?;
    final exitType = trade['exit_type']   as String?;
    final isPos    = (pnl ?? 0) >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(trade['ticker'] as String? ?? '–',
                        style: const TextStyle(
                            color: KestrelColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    if (exitType != null) ...[
                      const SizedBox(width: 6),
                      _ExitBadge(
                          label: exitType,
                          color: _badgeColor(exitType)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(_fmtDate(trade['exit_date'] as String?),
                    style: const TextStyle(
                        color: KestrelColors.textGrey, fontSize: 10)),
              ],
            ),
          ),
          if (pnl != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isPos ? '+' : ''}${pnl.toStringAsFixed(2)} €',
                  style: TextStyle(
                      color: isPos ? KestrelColors.green : KestrelColors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isPos ? '+' : ''}${(pnlPct ?? 0).toStringAsFixed(1)} %',
                  style: TextStyle(
                      color: isPos ? KestrelColors.green : KestrelColors.red,
                      fontSize: 10),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Exit Type Badge ───────────────────────────────────────────

class _ExitBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const _ExitBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border:       Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Run Log ───────────────────────────────────────────────────

class _PaperRunLog extends StatelessWidget {
  final List runs;
  const _PaperRunLog({required this.runs});

  String _fmtRunDateTime(Map<String, dynamic> run) {
    final ts = run['timestamp'] as String?;
    if (ts != null && ts.length >= 16) {
      final tIdx = ts.indexOf('T');
      if (tIdx > 0) {
        final dateParts = ts.substring(0, tIdx).split('-');
        final timePart  = ts.substring(tIdx + 1, tIdx + 6);
        if (dateParts.length == 3) {
          return '${dateParts[2]}.${dateParts[1]}. · $timePart';
        }
      }
    }
    final runId = run['run_id'] as String? ?? '';
    if (runId.length >= 13) {
      final day   = runId.substring(6, 8);
      final month = runId.substring(4, 6);
      final hour  = runId.substring(9, 11);
      final min   = runId.substring(11, 13);
      return '$day.$month. · $hour:$min';
    }
    return '–';
  }

  @override
  Widget build(BuildContext context) {
    final display = runs.take(10).toList();
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
          const Text('RUN-LOG',
              style: TextStyle(
                  color:         KestrelColors.gold,
                  fontSize:      10,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 4),
          if (display.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Noch keine Runs aufgezeichnet',
                    style: TextStyle(
                        color: KestrelColors.textGrey, fontSize: 12)),
              ),
            )
          else
            ...display.map(
              (r) => _PaperRunRow(
                run:          r as Map<String, dynamic>,
                fmtDateTime:  _fmtRunDateTime(r),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaperRunRow extends StatelessWidget {
  final Map<String, dynamic> run;
  final String               fmtDateTime;
  const _PaperRunRow({required this.run, required this.fmtDateTime});

  @override
  Widget build(BuildContext context) {
    final accepted  = (run['accepted'] as num?)?.toInt() ?? 0;
    final screened  = (run['screened'] as num?)?.toInt() ?? 0;
    final marketOk  = run['market_ok'] as bool? ?? true;
    final hasAccepted = accepted > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 10,
            child: hasAccepted
                ? Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: KestrelColors.gold,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              fmtDateTime,
              style: const TextStyle(
                  color: KestrelColors.textGrey, fontSize: 12),
            ),
          ),
          Text(
            '$accepted / $screened',
            style: TextStyle(
                color: hasAccepted
                    ? KestrelColors.textPrimary
                    : KestrelColors.textDimmed,
                fontSize:   12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          _ExitBadge(
            label: marketOk ? 'Markt OK' : 'Markt geblockt',
            color: marketOk ? KestrelColors.green : KestrelColors.orange,
          ),
        ],
      ),
    );
  }
}

// ── Stat Cell (local copy of history_screen._StatCell) ────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  const _StatCell(
      {required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        KestrelColors.screenBg,
        borderRadius: BorderRadius.circular(7),
        border:       Border.all(color: KestrelColors.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: valueColor ?? KestrelColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: KestrelColors.textGrey, fontSize: 9)),
        ],
      ),
    );
  }
}
