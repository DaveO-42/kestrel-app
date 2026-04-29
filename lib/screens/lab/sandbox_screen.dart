import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/kestrel_theme.dart';

class SandboxScreen extends StatefulWidget {
  const SandboxScreen({super.key});

  @override
  State<SandboxScreen> createState() => _SandboxScreenState();
}

class _SandboxScreenState extends State<SandboxScreen>
    with TickerProviderStateMixin {

  // ── Parameter ──────────────────────────────────────────────
  double         _atrMultiplier = 2.0;
  double         _rsiMin        = 50;
  double         _rsiMax        = 70;
  double         _minPerf       = 3.0;
  final Set<int> _years         = {2022, 2023, 2024};

  // ── Job State ──────────────────────────────────────────────
  String?               _jobId;
  String                _jobMessage = '';
  int                   _jobCurrent = 0;
  int                   _jobTotal   = 3;
  Map<String, dynamic>? _result;
  String?               _error;
  bool                  _running    = false;
  bool                  _cancelling = false;
  Timer?                _pollTimer;
  Timer?                _cancelTimer;

  // ── Hover Animation ────────────────────────────────────────
  late final AnimationController _hoverCtrl;
  late final Animation<double>   _hoverAnim;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _hoverAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    _pollTimer?.cancel();
    _cancelTimer?.cancel();
    super.dispose();
  }

  // ── Run ────────────────────────────────────────────────────
  Future<void> _startRun() async {
    if (_years.isEmpty) return;
    setState(() {
      _running    = true;
      _result     = null;
      _error      = null;
      _jobMessage = 'Starte…';
      _jobCurrent = 0;
      _jobTotal   = _years.length;
    });
    try {
      final res = await ApiService.postSandboxRun(
        atrMultiplier: _atrMultiplier,
        rsiMin:        _rsiMin.round(),
        rsiMax:        _rsiMax.round(),
        minPerfPct:    _minPerf,
        years:         _years.toList()..sort(),
      );
      _jobId = res['job_id'] as String?;
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    } catch (e) {
      setState(() { _running = false; _error = e.toString(); });
    }
  }

  Future<void> _poll() async {
    if (_jobId == null) return;
    try {
      final s = await ApiService.getSandboxStatus(_jobId!);
      final status = s['status'] as String? ?? '';
      setState(() {
        _jobMessage = s['message'] as String? ?? '';
        _jobCurrent = (s['current'] as num?)?.toInt() ?? 0;
        _jobTotal   = (s['total']   as num?)?.toInt() ?? 3;
      });
      if (status == 'done') {
        _pollTimer?.cancel();
        setState(() { _running = false; _result = s['result'] as Map<String, dynamic>?; });
      } else if (status == 'cancelled') {
        _pollTimer?.cancel();
        _cancelTimer?.cancel();
        setState(() { _running = false; _cancelling = false; });
      } else if (status == 'error') {
        _pollTimer?.cancel();
        setState(() { _running = false; _error = s['error'] as String? ?? 'Fehler'; });
      }
    } catch (_) {}
  }

  Future<void> _cancelRun() async {
    if (_jobId == null) return;
    setState(() => _cancelling = true);
    try { await ApiService.postSandboxCancel(_jobId!); } catch (_) {}
    _cancelTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted) return;
      _pollTimer?.cancel();
      setState(() {
        _running    = false;
        _cancelling = false;
        _error      = 'Job läuft noch im Hintergrund. Bitte 30 Sekunden warten.';
        _jobId      = null;
        _jobMessage = '';
        _jobCurrent = 0;
      });
    });
  }

  void _reset() {
    _pollTimer?.cancel();
    _cancelTimer?.cancel();
    setState(() {
      _running    = false;
      _cancelling = false;
      _result     = null;
      _error      = null;
      _jobId      = null;
      _jobMessage = '';
      _jobCurrent = 0;
    });
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_running) return _buildRunningScreen();
    if (_result != null) return _buildResultsScreen();
    return _buildParamsScreen();
  }

  // ═══════════════════════════════════════════════════════════
  // PARAMETER SCREEN
  // ═══════════════════════════════════════════════════════════

  Widget _buildParamsScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            _ErrorBanner(message: _error!, onDismiss: () => setState(() => _error = null)),
            const SizedBox(height: 10),
          ],

          // ── ATR ───────────────────────────────────────────
          _ParamCard(
            label: 'STOP-MULTIPLIKATOR',
            child: _ParamSlider(
              value:     _atrMultiplier,
              min:       1.0,
              max:       4.0,
              divisions: 12,
              display:   'ATR × ${_atrMultiplier.toStringAsFixed(1)}',
              baseline:  2.0,
              onChanged: (v) => setState(() => _atrMultiplier = v),
            ),
          ),
          const SizedBox(height: 8),

          // ── RSI ───────────────────────────────────────────
          _ParamCard(
            label: 'RSI-BEREICH',
            child: Column(
              children: [
                _ParamSlider(
                  value:     _rsiMin,
                  min:       30,
                  max:       65,
                  divisions: 35,
                  display:   'Min  ${_rsiMin.round()}',
                  baseline:  50,
                  onChanged: (v) => setState(() {
                    _rsiMin = v;
                    if (_rsiMin >= _rsiMax) _rsiMax = _rsiMin + 5;
                  }),
                ),
                const SizedBox(height: 4),
                _ParamSlider(
                  value:     _rsiMax,
                  min:       55,
                  max:       85,
                  divisions: 30,
                  display:   'Max  ${_rsiMax.round()}',
                  baseline:  70,
                  onChanged: (v) => setState(() {
                    _rsiMax = v;
                    if (_rsiMax <= _rsiMin) _rsiMin = _rsiMax - 5;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Performance ───────────────────────────────────
          _ParamCard(
            label: 'MIN. PERFORMANCE NACH BEAT',
            child: _ParamSlider(
              value:     _minPerf,
              min:       0.0,
              max:       10.0,
              divisions: 20,
              display:   '+${_minPerf.toStringAsFixed(1)} %',
              baseline:  3.0,
              onChanged: (v) => setState(() => _minPerf = v),
            ),
          ),
          const SizedBox(height: 8),

          // ── Zeitraum ──────────────────────────────────────
          _ParamCard(
            label: 'ZEITRAUM',
            child: Row(
              children: [2022, 2023, 2024].map((y) {
                final on = _years.contains(y);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (on && _years.length > 1) _years.remove(y);
                        else _years.add(y);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: on ? KestrelColors.goldBg : KestrelColors.innerBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: on
                                ? KestrelColors.goldBorder
                                : KestrelColors.cardBorder,
                            width: on ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$y',
                          style: TextStyle(
                            color:      on ? KestrelColors.gold : KestrelColors.textDimmed,
                            fontSize:   13,
                            fontWeight: on ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // ── CTA ───────────────────────────────────────────
          ElevatedButton(
            onPressed: _years.isNotEmpty ? _startRun : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:  KestrelColors.gold,
              foregroundColor:  KestrelColors.appBarBg,
              disabledBackgroundColor: KestrelColors.cardBorder,
              padding:          const EdgeInsets.symmetric(vertical: 14),
              shape:            RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text(
              'Backtest starten',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // RUNNING SCREEN
  // ═══════════════════════════════════════════════════════════

  Widget _buildRunningScreen() {
    final sortedYears = _years.toList()..sort();
    final pct = _jobTotal > 0 ? _jobCurrent / _jobTotal : 0.0;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hover Logo
                  AnimatedBuilder(
                    animation: _hoverAnim,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, _hoverAnim.value),
                      child: Opacity(
                        opacity: _cancelling ? 0.4 : 1.0,
                        child: const KestrelLogo(size: 88),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Status Message
                  Text(
                    _cancelling ? 'Wird abgebrochen…' : _jobMessage,
                    style: TextStyle(
                      color:      _cancelling
                          ? KestrelColors.textDimmed
                          : KestrelColors.textPrimary,
                      fontSize:   15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value:           _cancelling ? null : pct,
                      minHeight:       4,
                      backgroundColor: KestrelColors.cardBorder,
                      valueColor:      AlwaysStoppedAnimation(
                        _cancelling
                            ? KestrelColors.textDimmed
                            : KestrelColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Jahr-Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: sortedYears.asMap().entries.map((e) {
                      final idx    = e.key;
                      final year   = e.value;
                      final done   = idx < _jobCurrent;
                      final active = idx == _jobCurrent && !_cancelling;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            Text(
                              done ? '✓' : active ? '●' : '○',
                              style: TextStyle(
                                color: done
                                    ? KestrelColors.green
                                    : active
                                    ? KestrelColors.gold
                                    : KestrelColors.textHint,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$year',
                              style: TextStyle(
                                color: done
                                    ? KestrelColors.green
                                    : active
                                    ? KestrelColors.gold
                                    : KestrelColors.textDimmed,
                                fontSize:   12,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Abbrechen Button (sticky bottom)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: GestureDetector(
            onTap: _cancelling ? null : _cancelRun,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _cancelling
                      ? KestrelColors.cardBorder.withOpacity(0.3)
                      : KestrelColors.cardBorder,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _cancelling ? 'Bitte warten…' : 'Abbrechen',
                style: TextStyle(
                  color:    _cancelling
                      ? KestrelColors.textHint
                      : KestrelColors.textDimmed,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // RESULTS SCREEN
  // ═══════════════════════════════════════════════════════════

  Widget _buildResultsScreen() {
    final yearResults = (_result?['year_results'] as Map<String, dynamic>?) ?? {};
    final total       = (_result?['total']        as Map<String, dynamic>?) ?? {};
    final params      = (_result?['params']        as Map<String, dynamic>?) ?? {};
    final sortedYears = (yearResults.keys.toList()..sort());
    final multiYear   = sortedYears.length > 1;
    final hasTotal    = total.isNotEmpty && total['error'] == null;

    // Baseline: Original-Backtest 2022–2024 (ATR×2.0, RSI 50–70, Perf >3%)
    const _baseline = {
      'all':  {'n': 64,  'win': 43.8, 'avg': 2.48,  'sharpe': 0.64},
      '2022': {'n': 15,  'win': 46.7, 'avg': 1.32,  'sharpe': 0.66},
      '2023': {'n': 30,  'win': 36.7, 'avg': 2.56,  'sharpe': 0.50},
      '2024': {'n': 19,  'win': 52.6, 'avg': 3.28,  'sharpe': 1.16},
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Params Summary ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: kCardDecoration(),
            child: Row(
              children: [
                _ParamPill('ATR ×${params['atr_multiplier']}'),
                const SizedBox(width: 6),
                _ParamPill('RSI ${params['rsi_min']}–${params['rsi_max']}'),
                const SizedBox(width: 6),
                _ParamPill('Perf >${params['min_perf_pct']}%'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Total Card ────────────────────────────────────
          if (multiYear) ...[
            Container(
              decoration: kCardDecoration(goldTop: true),
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('GESAMT',
                          style: TextStyle(
                            color:         KestrelColors.gold,
                            fontSize:      10,
                            fontWeight:    FontWeight.w700,
                            letterSpacing: 0.8,
                          )),
                      if (hasTotal) _PnlBadge(total),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (hasTotal) ...[
                    _MetricsRow(total),
                    // ── Gegenüberstellung Baseline ─────────
                    if (sortedYears.length == 3) ...[
                      const SizedBox(height: 10),
                      _BaselineComparison(
                        sandbox:  total,
                        baseline: _baseline['all']!,
                      ),
                    ],
                  ] else
                    const Text('Keine Trades',
                        style: TextStyle(
                            color: KestrelColors.textGrey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── Jahr-Cards ────────────────────────────────────
          ...sortedYears.map((year) {
            final m        = yearResults[year] as Map<String, dynamic>? ?? {};
            final hasData  = m.isNotEmpty && m['error'] == null;
            final baseline = _baseline[year] as Map<String, dynamic>?;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: kCardDecoration(),
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(year,
                            style: const TextStyle(
                              color:         KestrelColors.textGrey,
                              fontSize:      10,
                              fontWeight:    FontWeight.w700,
                              letterSpacing: 0.8,
                            )),
                        if (hasData) _PnlBadge(m),
                      ],
                    ),
                    if (!hasData)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                            m['error'] as String? ?? 'Keine Daten',
                            style: const TextStyle(
                                color: KestrelColors.textGrey, fontSize: 12)),
                      )
                    else ...[
                      const SizedBox(height: 10),
                      _MetricsRow(m),
                      if (baseline != null) ...[
                        const SizedBox(height: 10),
                        _BaselineComparison(
                          sandbox:  m,
                          baseline: baseline,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 4),

          // ── Neue Konfiguration ────────────────────────────
          GestureDetector(
            onTap: _reset,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: KestrelColors.cardBorder),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Neue Konfiguration',
                style: TextStyle(color: KestrelColors.textDimmed, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// HILFS-WIDGETS
// ═══════════════════════════════════════════════════════════

// ── Param Card ─────────────────────────────────────────────

class _ParamCard extends StatelessWidget {
  final String label;
  final Widget child;
  const _ParamCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: kCardDecoration(),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                color:         KestrelColors.gold,
                fontSize:      10,
                fontWeight:    FontWeight.w700,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── Param Slider ───────────────────────────────────────────

class _ParamSlider extends StatelessWidget {
  final double value, min, max, baseline;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  const _ParamSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.baseline,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final changed = (value - baseline).abs() > 0.05;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            display,
            style: TextStyle(
              color:      changed ? KestrelColors.gold : KestrelColors.textPrimary,
              fontSize:   14,
              fontWeight: changed ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor:   KestrelColors.gold,
              inactiveTrackColor: KestrelColors.cardBorder,
              thumbColor:         KestrelColors.gold,
              overlayColor:       KestrelColors.gold.withOpacity(0.15),
              trackHeight:        2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value:     value,
              min:       min,
              max:       max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Metrics Row ────────────────────────────────────────────

class _MetricsRow extends StatelessWidget {
  final Map<String, dynamic> m;
  const _MetricsRow(this.m);

  @override
  Widget build(BuildContext context) {
    final n      = '${m['trades_total'] ?? '–'}';
    final win    = m['win_rate_pct'] != null ? '${m['win_rate_pct']}%' : '–';
    final avg    = (m['avg_return_pct'] as num?)?.toDouble();
    final dd     = (m['max_drawdown_pct'] as num?)?.toDouble();
    final sharpe = m['sharpe_ratio'];

    return Container(
      decoration: kInnerCellDecoration(),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          _StatCell(value: n,                                            label: 'Trades'),
          _StatCell(value: win,                                          label: 'Win%'),
          _StatCell(
            value: avg != null ? '${avg >= 0 ? '+' : ''}${avg.toStringAsFixed(1)}%' : '–',
            label: 'Ø Rendite',
            valueColor: avg == null ? null : avg >= 0 ? KestrelColors.green : KestrelColors.red,
          ),
          _StatCell(value: dd  != null ? '${dd.toStringAsFixed(1)}%'   : '–', label: 'MaxDD'),
          _StatCell(value: sharpe != null ? '$sharpe'                   : '–', label: 'Sharpe'),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value, label;
  final Color? valueColor;
  const _StatCell({required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value,
            style: TextStyle(
              color:      valueColor ?? KestrelColors.textPrimary,
              fontSize:   13,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
              color:   KestrelColors.textDimmed,
              fontSize: 9,
            )),
      ],
    ),
  );
}

// ── P&L Badge ──────────────────────────────────────────────

class _PnlBadge extends StatelessWidget {
  final Map<String, dynamic> m;
  const _PnlBadge(this.m);

  @override
  Widget build(BuildContext context) {
    final pnl     = (m['total_pnl_eur'] as num?)?.toDouble();
    if (pnl == null) return const SizedBox.shrink();
    final pos     = pnl >= 0;
    final label   = '${pos ? '+' : ''}€${pnl.toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        pos ? KestrelColors.greenBg  : KestrelColors.redBg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: pos ? KestrelColors.greenBorder : KestrelColors.redBorder,
        ),
      ),
      child: Text(label,
          style: TextStyle(
            color:      pos ? KestrelColors.green : KestrelColors.red,
            fontSize:   12,
            fontWeight: FontWeight.w700,
          )),
    );
  }
}

// ── Param Pill ─────────────────────────────────────────────

class _ParamPill extends StatelessWidget {
  final String label;
  const _ParamPill(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color:        KestrelColors.innerBg,
      borderRadius: BorderRadius.circular(5),
      border:       Border.all(color: KestrelColors.cardBorder),
    ),
    child: Text(label,
        style: const TextStyle(
          color:   KestrelColors.textGrey,
          fontSize: 11,
        )),
  );
}

// ── Baseline Comparison ────────────────────────────────────────

class _BaselineComparison extends StatelessWidget {
  final Map<String, dynamic> sandbox;
  final Map<String, dynamic> baseline;
  const _BaselineComparison({required this.sandbox, required this.baseline});

  @override
  Widget build(BuildContext context) {
    final sWin    = (sandbox['win_rate_pct']  as num?)?.toDouble() ?? 0;
    final sAvg    = (sandbox['avg_return_pct'] as num?)?.toDouble() ?? 0;
    final sSharpe = (sandbox['sharpe_ratio']   as num?)?.toDouble() ?? 0;

    final bWin    = (baseline['win']    as num).toDouble();
    final bAvg    = (baseline['avg']    as num).toDouble();
    final bSharpe = (baseline['sharpe'] as num).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color:        KestrelColors.innerBg,
        borderRadius: BorderRadius.circular(7),
        border:       Border.all(color: KestrelColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VS. BASELINE  (ATR×2.0 · RSI 50–70 · Perf >3%)',
            style: TextStyle(
              color:         KestrelColors.textDimmed,
              fontSize:      9,
              letterSpacing: 0.6,
              fontWeight:    FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _DeltaCell('Win%',   sWin,    bWin,    '%'),
              _DeltaCell('Ø Ret',  sAvg,    bAvg,    '%'),
              _DeltaCell('Sharpe', sSharpe, bSharpe, ''),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeltaCell extends StatelessWidget {
  final String label;
  final double sandbox, baseline;
  final String unit;
  const _DeltaCell(this.label, this.sandbox, this.baseline, this.unit);

  @override
  Widget build(BuildContext context) {
    final delta   = sandbox - baseline;
    final better  = delta > 0;
    final neutral = delta.abs() < 0.05;
    final color   = neutral
        ? KestrelColors.textDimmed
        : better
        ? KestrelColors.green
        : KestrelColors.red;
    final arrow   = neutral ? '' : better ? ' ▲' : ' ▼';

    return Expanded(
      child: Column(
        children: [
          Text(
            '${delta >= 0 && !neutral ? '+' : ''}${delta.toStringAsFixed(1)}$unit$arrow',
            style: TextStyle(
              color:      color,
              fontSize:   12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$label  (${baseline.toStringAsFixed(1)}$unit)',
            style: const TextStyle(
              color:   KestrelColors.textHint,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error Banner ───────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
    decoration: BoxDecoration(
      color:        KestrelColors.redBg,
      borderRadius: BorderRadius.circular(8),
      border:       Border.all(color: KestrelColors.redBorder),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: KestrelColors.red, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: const TextStyle(color: KestrelColors.red, fontSize: 12))),
        GestureDetector(
          onTap: onDismiss,
          child: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.close, color: KestrelColors.red, size: 15),
          ),
        ),
      ],
    ),
  );
}