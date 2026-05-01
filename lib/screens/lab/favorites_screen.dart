import 'package:flutter/material.dart';
import '../../theme/kestrel_theme.dart';
import 'sandbox_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => FavoritesScreenState();
}

class FavoritesScreenState extends State<FavoritesScreen> {
  List<SavedConfig> _configs  = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final configs = await loadFavorites();
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
    final configs = await loadFavorites();
    configs.removeWhere((c) => c.id == id);
    await saveFavorites(configs);
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Config-Liste ──────────────────────────────────
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

          // ── Vergleich-Button ──────────────────────────────
          if (_configs.isNotEmpty) ...[
            const SizedBox(height: 4),
            ElevatedButton(
              onPressed: canCompare ? () {} : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:        canCompare
                    ? KestrelColors.gold : KestrelColors.cardBg,
                foregroundColor:        canCompare
                    ? KestrelColors.appBarBg : KestrelColors.textHint,
                disabledBackgroundColor: KestrelColors.innerBg,
                disabledForegroundColor: KestrelColors.textHint,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size.fromHeight(40),
              ),
              child: Text(canCompare
                  ? 'Vergleichen'
                  : 'Zwei Konfigurationen auswählen'),
            ),
          ],

          // ── Vergleichs-Card ───────────────────────────────
          if (canCompare && selected.length == 2) ...[
            const SizedBox(height: 12),
            _ComparisonCard(
              a:         selected[0],
              b:         selected[1],
              onDeleteA: () => _delete(selected[0].id),
              onDeleteB: () => _delete(selected[1].id),
            ),
          ],
        ],
      ),
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
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: KestrelColors.textHint),
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
    final aSharpe = (a.results['total']?['sharpe_ratio'] as num?)
            ?.toDouble() ??
        0;
    final bSharpe = (b.results['total']?['sharpe_ratio'] as num?)
            ?.toDouble() ??
        0;
    final aWins = aSharpe >= bSharpe;

    return Container(
      decoration: kCardDecoration(goldTop: true),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VERGLEICH', style: kCardLabelStyle),
          const SizedBox(height: 10),
          _ComparedConfig(
            config:   a,
            other:    b,
            isBetter: aWins,
            onDelete: onDeleteA,
          ),
          const SizedBox(height: 6),
          _ComparedConfig(
            config:   b,
            other:    a,
            isBetter: !aWins,
            onDelete: onDeleteB,
          ),
        ],
      ),
    );
  }
}

// ── Compared Config ────────────────────────────────────────

class _ComparedConfig extends StatelessWidget {
  final SavedConfig  config, other;
  final bool         isBetter;
  final VoidCallback onDelete;
  const _ComparedConfig({
    required this.config,
    required this.other,
    required this.isBetter,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final m  = config.results['total'] as Map<String, dynamic>? ?? {};
    final mo = other.results['total']  as Map<String, dynamic>? ?? {};

    final win     = (m['win_rate_pct']    as num?)?.toDouble();
    final ret     = (m['avg_return_pct']  as num?)?.toDouble();
    final sharpe  = (m['sharpe_ratio']    as num?)?.toDouble();
    final bWin    = (mo['win_rate_pct']   as num?)?.toDouble();
    final bRet    = (mo['avg_return_pct'] as num?)?.toDouble();
    final bSharpe = (mo['sharpe_ratio']   as num?)?.toDouble();

    return Container(
      decoration: BoxDecoration(
        color:        KestrelColors.innerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBetter
              ? KestrelColors.green : KestrelColors.cardBorder,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(11, 9, 8, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(config.name,
                    style: TextStyle(
                      color:      isBetter
                          ? KestrelColors.green
                          : KestrelColors.textGrey,
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                    )),
                if (isBetter) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color:        KestrelColors.greenBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: KestrelColors.greenBorder),
                    ),
                    child: const Text('Besser',
                        style: TextStyle(
                            color:      KestrelColors.green,
                            fontSize:   9,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: KestrelColors.textHint),
                onPressed: onDelete,
                padding:     EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (win != null && bWin != null)
                _DeltaMetric(
                  label:  'Win%',
                  value:  win,
                  delta:  win - bWin,
                  format: (v) => '${v.toStringAsFixed(1)}%',
                ),
              if (ret != null && bRet != null)
                _DeltaMetric(
                  label:  'Ø Ret',
                  value:  ret,
                  delta:  ret - bRet,
                  format: (v) =>
                      '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%',
                ),
              if (sharpe != null && bSharpe != null)
                _DeltaMetric(
                  label:  'Sharpe',
                  value:  sharpe,
                  delta:  sharpe - bSharpe,
                  format: (v) => v.toStringAsFixed(2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Delta Metric ───────────────────────────────────────────

class _DeltaMetric extends StatelessWidget {
  final String label;
  final double value, delta;
  final String Function(double) format;
  const _DeltaMetric({
    required this.label,
    required this.value,
    required this.delta,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final rounded = double.parse(delta.toStringAsFixed(1));
    final neutral = rounded == 0.0;
    final better  = delta > 0;
    final color   = neutral
        ? KestrelColors.gold
        : better ? KestrelColors.green : KestrelColors.red;
    final arrow   = neutral ? '' : better ? ' ▲' : ' ▼';
    final deltaStr = rounded == 0.0
        ? ''
        : ' ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}$arrow';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(format(value),
            style: TextStyle(
                color:      color,
                fontSize:   13,
                fontWeight: FontWeight.w700)),
        Text('$label$deltaStr',
            style: const TextStyle(
                color: KestrelColors.textDimmed, fontSize: 9)),
      ],
    );
  }
}
