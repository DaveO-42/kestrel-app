import 'package:flutter/material.dart';
import '../../theme/kestrel_theme.dart';
import 'sandbox_screen.dart';
import 'package:material_symbols_icons/symbols.dart';

class SetupsScreen extends StatefulWidget {
  const SetupsScreen({super.key});

  @override
  State<SetupsScreen> createState() => SetupsScreenState();
}

class SetupsScreenState extends State<SetupsScreen> {
  List<SavedConfig> _configs  = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final configs = await loadSetups();
    if (!mounted) return;
    setState(() => _configs = configs);
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < 2) {
        _selected.add(id);
      }
    });
  }

  Future<void> _delete(String id) async {
    final configs = await loadSetups();
    configs.removeWhere((c) => c.id == id);
    await saveSetups(configs);
    setState(() {
      _configs.removeWhere((c) => c.id == id);
      _selected.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final canCompare = _selected.length == 2;
    final selected   = _configs
        .where((c) => _selected.contains(c.id))
        .toList();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Config-Liste ────────────────────────────
                if (_configs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: kCardDecoration(),
                    child: const Center(
                      child: Text(
                        'Noch keine Konfigurationen gespeichert.\n'
                        'Nach einem Sandbox-Run auf „Speichern" tippen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: KestrelColors.textDimmed, fontSize: 12),
                      ),
                    ),
                  )
                else ...[
                  const Text('KONFIGURATIONEN', style: kCardLabelStyle),
                  const SizedBox(height: 8),
                  ..._configs.map((c) => _ConfigCard(
                    config:   c,
                    selected: _selected.contains(c.id),
                    disabled: _selected.length == 2 &&
                              !_selected.contains(c.id),
                    onTap:    () => _toggle(c.id),
                    onDelete: () => _delete(c.id),
                  )),
                ],

                // ── Hinweis ──────────────────────────────────
                if (_configs.isNotEmpty && !canCompare) ...[
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Zwei Konfigurationen auswählen zum Vergleichen',
                      style: TextStyle(
                          color: KestrelColors.textDimmed, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Fixiertes Vergleichs-Panel ────────────────────
        if (canCompare && selected.length == 2) ...[
          Container(height: 1, color: KestrelColors.cardBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: _ComparisonCard(
              a:         selected[0],
              b:         selected[1],
              onDeleteA: () => _delete(selected[0].id),
              onDeleteB: () => _delete(selected[1].id),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Config Card ────────────────────────────────────────────

class _ConfigCard extends StatelessWidget {
  final SavedConfig   config;
  final bool          selected;
  final bool          disabled;
  final VoidCallback  onTap;
  final VoidCallback  onDelete;
  const _ConfigCard({
    required this.config,
    required this.selected,
    required this.disabled,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color:        selected
                ? KestrelColors.cardBg : KestrelColors.innerBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? KestrelColors.gold : KestrelColors.cardBorder,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width:  8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color:  selected
                      ? KestrelColors.gold : KestrelColors.cardBorder,
                  shape:  BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(config.name,
                            style: TextStyle(
                              color:      selected
                                  ? KestrelColors.gold
                                  : KestrelColors.textGrey,
                              fontSize:   13,
                              fontWeight: FontWeight.w700,
                            )),
                        Text(config.date,
                            style: const TextStyle(
                                color:    KestrelColors.textDimmed,
                                fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(spacing: 5, children: [
                      ParamPill('ATR ×${config.atr}'),
                      ParamPill(
                          'RSI ${config.rsiMin}–${config.rsiMax}'),
                      ParamPill('Perf >${config.minPerf}%'),
                    ]),
                    if (config.results['total'] != null) ...[
                      const SizedBox(height: 5),
                      _MiniMetrics(
                          config.results['total']
                          as Map<String, dynamic>),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Symbols.delete,
                    size: 18, color: KestrelColors.textDimmed),
                onPressed: onDelete,
                padding:     EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mini Metrics ───────────────────────────────────────────

class _MiniMetrics extends StatelessWidget {
  final Map<String, dynamic> m;
  const _MiniMetrics(this.m);

  @override
  Widget build(BuildContext context) {
    final win    = (m['win_rate_pct']   as num?)?.toStringAsFixed(1);
    final ret    = (m['avg_return_pct'] as num?)?.toStringAsFixed(1);
    final sharpe = (m['sharpe_ratio']   as num?)?.toStringAsFixed(2);
    return Row(children: [
      if (win    != null) _M('Win $win%'),
      if (ret    != null) _M('Ø +$ret%'),
      if (sharpe != null) _M('Sharpe $sharpe'),
    ]);
  }

  Widget _M(String t) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Text(t,
        style: const TextStyle(
            color: KestrelColors.textDimmed, fontSize: 10)),
  );
}

// ── Comparison Card ────────────────────────────────────────

class _ComparisonCard extends StatelessWidget {
  final SavedConfig  a, b;
  final VoidCallback onDeleteA, onDeleteB;
  const _ComparisonCard({
    required this.a,
    required this.b,
    required this.onDeleteA,
    required this.onDeleteB,
  });

  @override
  Widget build(BuildContext context) {
    final aSharpe  = (a.results['total']?['sharpe_ratio'] as num?)?.toDouble() ?? 0;
    final bSharpe  = (b.results['total']?['sharpe_ratio'] as num?)?.toDouble() ?? 0;
    final aWins    = aSharpe >= bSharpe;
    final aMetrics = a.results['total'] as Map<String, dynamic>? ?? {};
    final bMetrics = b.results['total'] as Map<String, dynamic>? ?? {};

    return KGoldTopCard(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VERGLEICH', style: kCardLabelStyle),
          const SizedBox(height: 10),

          // ── Header: names ──────────────────────────────
          Row(
            children: [
              const SizedBox(width: 80),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(a.name,
                        style: TextStyle(
                          color:      aWins
                              ? KestrelColors.green : KestrelColors.textGrey,
                          fontSize:   12,
                          fontWeight: FontWeight.w700,
                        )),
                    if (aWins) ...[
                      const SizedBox(width: 5),
                      const _BesserBadge(),
                    ],
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onDeleteA,
                      child: const Icon(Symbols.delete,
                          size: 14, color: KestrelColors.textDimmed),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(b.name,
                        style: TextStyle(
                          color:      !aWins
                              ? KestrelColors.green : KestrelColors.textGrey,
                          fontSize:   12,
                          fontWeight: FontWeight.w700,
                        )),
                    if (!aWins) ...[
                      const SizedBox(width: 5),
                      const _BesserBadge(),
                    ],
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onDeleteB,
                      child: const Icon(Symbols.delete,
                          size: 14, color: KestrelColors.textDimmed),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Container(height: 1, color: KestrelColors.cardBorder),
          const SizedBox(height: 4),

          // ── Metric rows ────────────────────────────────
          _CmpRow(
            label: 'Win%',
            aVal:  (aMetrics['win_rate_pct']   as num?)?.toDouble(),
            bVal:  (bMetrics['win_rate_pct']   as num?)?.toDouble(),
            fmt:   (v) => v != null ? '${v.toStringAsFixed(1)}%' : '–',
          ),
          _CmpRow(
            label: 'Ø Rendite',
            aVal:  (aMetrics['avg_return_pct'] as num?)?.toDouble(),
            bVal:  (bMetrics['avg_return_pct'] as num?)?.toDouble(),
            fmt:   (v) => v != null
                ? '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%'
                : '–',
          ),
          _CmpRow(
            label: 'Sharpe',
            aVal:  (aMetrics['sharpe_ratio']   as num?)?.toDouble(),
            bVal:  (bMetrics['sharpe_ratio']   as num?)?.toDouble(),
            fmt:   (v) => v != null ? v.toStringAsFixed(2) : '–',
          ),
        ],
      ),
    );
  }
}

// ── Cmp Row ────────────────────────────────────────────────

class _CmpRow extends StatelessWidget {
  final String label;
  final double? aVal, bVal;
  final String Function(double?) fmt;
  const _CmpRow({
    required this.label,
    required this.aVal,
    required this.bVal,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final aBetter = aVal != null && bVal != null && aVal! > bVal!;
    final bBetter = aVal != null && bVal != null && bVal! > aVal!;
    final delta   = (aVal != null && bVal != null)
        ? (aVal! - bVal!).abs().toStringAsFixed(1)
        : '–';
    // Arrow points toward winner: ◀ if a is better, ▶ if b is better
    final arrow   = aBetter ? '◀' : bBetter ? '▶' : '–';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: KestrelColors.textDimmed, fontSize: 11)),
          ),
          Expanded(
            child: Text(fmt(aVal),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:      aBetter ? KestrelColors.green
                      : bBetter ? KestrelColors.red
                      : KestrelColors.textPrimary,
                  fontSize:   12,
                  fontWeight: FontWeight.w700,
                )),
          ),
          SizedBox(
            width: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (aBetter) ...[
                  const Icon(Icons.arrow_left,
                      size: 14, color: KestrelColors.green),
                  Text(delta,
                      style: const TextStyle(
                          color: KestrelColors.textDimmed, fontSize: 10)),
                ] else if (bBetter) ...[
                  Text(delta,
                      style: const TextStyle(
                          color: KestrelColors.textDimmed, fontSize: 10)),
                  const Icon(Icons.arrow_right,
                      size: 14, color: KestrelColors.green),
                ] else
                  Text(delta,
                      style: const TextStyle(
                          color: KestrelColors.textDimmed, fontSize: 10)),
              ],
            ),
          ),
          Expanded(
            child: Text(fmt(bVal),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:      bBetter ? KestrelColors.green
                      : aBetter ? KestrelColors.red
                      : KestrelColors.textPrimary,
                  fontSize:   12,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
  }
}

// ── Besser Badge ───────────────────────────────────────────

class _BesserBadge extends StatelessWidget {
  const _BesserBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color:        KestrelColors.greenBg,
      borderRadius: BorderRadius.circular(4),
      border:       Border.all(color: KestrelColors.greenBorder),
    ),
    child: const Text('Besser',
        style: TextStyle(
            color:      KestrelColors.green,
            fontSize:   9,
            fontWeight: FontWeight.w600)),
  );
}

