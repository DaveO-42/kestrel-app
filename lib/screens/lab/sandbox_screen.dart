import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../theme/kestrel_theme.dart';

// ── Saved Config Model ─────────────────────────────────────────

class SavedConfig {
  final String id;
  final String name;
  final String date;
  final double atr;
  final int rsiMin;
  final int rsiMax;
  final double minPerf;
  final List<int> years;
  final Map<String, dynamic> results;

  const SavedConfig({
    required this.id,
    required this.name,
    required this.date,
    required this.atr,
    required this.rsiMin,
    required this.rsiMax,
    required this.minPerf,
    required this.years,
    required this.results,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'date': date,
    'atr': atr, 'rsiMin': rsiMin, 'rsiMax': rsiMax,
    'minPerf': minPerf, 'years': years, 'results': results,
  };

  factory SavedConfig.fromJson(Map<String, dynamic> j) => SavedConfig(
    id:      j['id']      as String,
    name:    j['name']    as String,
    date:    j['date']    as String,
    atr:     (j['atr']    as num).toDouble(),
    rsiMin:  j['rsiMin']  as int,
    rsiMax:  j['rsiMax']  as int,
    minPerf: (j['minPerf'] as num).toDouble(),
    years:   (j['years']  as List).cast<int>(),
    results: j['results'] as Map<String, dynamic>,
  );
}

const kSetupsKey = 'sandbox_setups';

Future<List<SavedConfig>> loadSetups() async {
  final prefs = await SharedPreferences.getInstance();
  final raw   = prefs.getStringList(kSetupsKey) ?? [];
  return raw
      .map((s) => SavedConfig.fromJson(
          jsonDecode(s) as Map<String, dynamic>))
      .toList();
}

Future<void> saveSetups(List<SavedConfig> configs) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(
      kSetupsKey,
      configs.map((c) => jsonEncode(c.toJson())).toList());
}

// ── Year Context ────────────────────────────────────────────────

const Map<int, String> _yearContext = {
  2022: 'Bärenjahr −33%',
  2023: 'Erholung +43%',
  2024: 'Bullenmarkt +25%',
  2025: 'Zoll-Schock −15%',
};

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
  CachedResult<Map<String, dynamic>>? _baselineResult;

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
    _load();
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

  void _showSaveDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: KestrelColors.cardBg,
        title: const Text('Konfiguration speichern',
            style: TextStyle(
                color: KestrelColors.textPrimary, fontSize: 14)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: KestrelColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Name (z.B. "Aggressiv")',
            hintStyle: TextStyle(color: KestrelColors.textHint),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: KestrelColors.cardBorder)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: KestrelColors.gold)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen',
                style: TextStyle(color: KestrelColors.textGrey)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final configs = await loadSetups();
              final now = DateTime.now();
              configs.insert(0, SavedConfig(
                id:      now.millisecondsSinceEpoch.toString(),
                name:    name,
                date:    '${now.day.toString().padLeft(2, '0')}.'
                         '${now.month.toString().padLeft(2, '0')}.'
                         '${now.year}',
                atr:     _atrMultiplier,
                rsiMin:  _rsiMin.round(),
                rsiMax:  _rsiMax.round(),
                minPerf: _minPerf,
                years:   _years.toList()..sort(),
                results: _result!,
              ));
              debugPrint('_result keys: ${_result!.keys.toList()}');
              debugPrint('_result total: ${_result!['total']}');
              await saveSetups(configs);
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('„$name" gespeichert'),
                  backgroundColor: KestrelColors.cardBg,
                ),
              );
            },
            child: const Text('Speichern',
                style: TextStyle(color: KestrelColors.gold)),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    try {
      final result = await ApiService.getSandboxBaseline();
      if (!mounted) return;
      setState(() => _baselineResult = result);
    } catch (_) {}
  }

  Map<String, dynamic>? _getBaselineForYear(String year) =>
      (_baselineResult?.data)?['year_results']?[year] as Map<String, dynamic>?;

  Map<String, dynamic>? get _baselineParams =>
      (_baselineResult?.data)?['params'] as Map<String, dynamic>?;
  double? get _baselineAtr   =>
      (_baselineParams?['atr_multiplier'] as num?)?.toDouble();
  int?    get _baselineRsiMin =>
      (_baselineParams?['rsi_min']        as num?)?.toInt();
  int?    get _baselineRsiMax =>
      (_baselineParams?['rsi_max']        as num?)?.toInt();
  double? get _baselinePerf  =>
      (_baselineParams?['min_perf_pct']   as num?)?.toDouble();

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
          Container(
            decoration: kCardDecoration(),
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
            child: _KestrelSlider(
              label:         'ATR-MULTIPLIKATOR',
              value:         _atrMultiplier,
              min:           1.0,
              max:           4.0,
              divisions:     30,
              unit:          '×',
              ticks:         const [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0],
              baselineValue: _baselineAtr,
              onChanged:     (v) => setState(() => _atrMultiplier = v),
            ),
          ),
          const SizedBox(height: 8),

          // ── RSI ───────────────────────────────────────────
          Container(
            decoration: kCardDecoration(),
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
            child: _KestrelRangeSlider(
              label:       'RSI-BEREICH',
              minValue:    _rsiMin,
              maxValue:    _rsiMax,
              min:         30,
              max:         85,
              divisions:   55,
              ticks:       const [30.0, 40.0, 50.0, 60.0, 70.0, 85.0],
              baselineMin: _baselineRsiMin?.toDouble(),
              baselineMax: _baselineRsiMax?.toDouble(),
              onChanged:   (v) => setState(() {
                _rsiMin = v.start.roundToDouble();
                _rsiMax = v.end.roundToDouble();
              }),
            ),
          ),
          const SizedBox(height: 8),

          // ── Performance ───────────────────────────────────
          Container(
            decoration: kCardDecoration(),
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
            child: _KestrelSlider(
              label:         'MIN. PERFORMANCE NACH BEAT',
              value:         _minPerf,
              min:           0.0,
              max:           10.0,
              divisions:     20,
              unit:          '+',
              ticks:         const [0.0, 2.0, 4.0, 6.0, 8.0, 10.0],
              baselineValue: _baselinePerf,
              onChanged:     (v) => setState(() => _minPerf = v),
            ),
          ),
          const SizedBox(height: 8),

          // ── Zeitraum ──────────────────────────────────────
          Container(
            decoration: kCardDecoration(),
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ZEITRÄUME', style: kCardLabelStyle),
                const SizedBox(height: 10),
                _YearGrid(
                  selected: _years,
                  onToggle: (year) => setState(() {
                    if (_years.contains(year)) {
                      if (_years.length > 1) _years.remove(year);
                    } else {
                      _years.add(year);
                    }
                  }),
                ),
              ],
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
    var   total       = (_result?['total']        as Map<String, dynamic>?) ?? {};
    final params      = (_result?['params']        as Map<String, dynamic>?) ?? {};
    final sortedYears = (yearResults.keys.toList()..sort());
    final multiYear   = sortedYears.length > 1;

    // Fallback: Gesamt clientseitig aus Jahres-Ergebnissen aggregieren
    if ((total.isEmpty || total['error'] != null) && yearResults.isNotEmpty) {
      var tTrades = 0;
      var tPnl    = 0.0;
      var tWin    = 0.0;
      var tAvg    = 0.0;
      var tSharpe = 0.0;
      var tDd     = 0.0;
      var count   = 0;
      for (final v in yearResults.values) {
        final m = v as Map?;
        if (m == null || m['error'] != null || m['trades_total'] == null) continue;
        if ((m['trades_total'] as num).toInt() <= 0) continue;
        tTrades += (m['trades_total'] as num).toInt();
        tPnl    += (m['total_pnl_eur']   as num?)?.toDouble() ?? 0;
        tWin    += (m['win_rate_pct']     as num?)?.toDouble() ?? 0;
        tAvg    += (m['avg_return_pct']   as num?)?.toDouble() ?? 0;
        tSharpe += (m['sharpe_ratio']     as num?)?.toDouble() ?? 0;
        final dd = (m['max_drawdown_pct'] as num?)?.toDouble() ?? 0;
        if (dd < tDd) tDd = dd;
        count++;
      }
      if (count > 0) {
        total = {
          'trades_total':     tTrades,
          'total_pnl_eur':    tPnl,
          'win_rate_pct':     double.parse((tWin / count).toStringAsFixed(1)),
          'avg_return_pct':   double.parse((tAvg / count).toStringAsFixed(2)),
          'max_drawdown_pct': tDd,
          'sharpe_ratio':     double.parse((tSharpe / count).toStringAsFixed(2)),
        };
      }
    }

    // hasTotal NACH dem Fallback evaluieren
    final hasTotal = total.isNotEmpty && total['error'] == null && (total['trades_total'] as num? ?? 0) > 0;

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
                ParamPill('ATR ×${params['atr_multiplier']}'),
                const SizedBox(width: 6),
                ParamPill('RSI ${params['rsi_min']}–${params['rsi_max']}'),
                const SizedBox(width: 6),
                ParamPill('Perf >${params['min_perf_pct']}%'),
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
                    _MetricsRow(total, baseline: _getBaselineForYear('all')),
                    if (_getBaselineForYear('all') != null) ...[
                      const SizedBox(height: 10),
                      _BaselineComparison(
                        sandbox:  total,
                        baseline: _getBaselineForYear('all')!,
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
            final baseline = _getBaselineForYear(year);

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
                      _MetricsRow(m, baseline: baseline),
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

          // ── Speichern ────────────────────────────────────
          ElevatedButton.icon(
            onPressed: _showSaveDialog,
            icon: const Icon(Icons.bookmark_add_outlined, size: 16),
            label: const Text('Konfiguration speichern'),
            style: ElevatedButton.styleFrom(
              backgroundColor: KestrelColors.cardBg,
              foregroundColor: KestrelColors.gold,
              side: const BorderSide(color: KestrelColors.cardBorder),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size.fromHeight(40),
            ),
          ),
          const SizedBox(height: 8),

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


// ── Metrics Row ────────────────────────────────────────────

Color _compareColor(double? val, double? base) {
  if (val == null || base == null) return KestrelColors.textPrimary;
  final delta = double.parse((val - base).toStringAsFixed(1));
  if (delta == 0.0) return KestrelColors.gold;
  return delta > 0 ? KestrelColors.green : KestrelColors.red;
}

class _MetricsRow extends StatelessWidget {
  final Map<String, dynamic> m;
  final Map<String, dynamic>? baseline;
  const _MetricsRow(this.m, {this.baseline});

  @override
  Widget build(BuildContext context) {
    final n      = '${m['trades_total'] ?? '–'}';
    final win    = (m['win_rate_pct']    as num?)?.toDouble();
    final avg    = (m['avg_return_pct']  as num?)?.toDouble();
    final dd     = (m['max_drawdown_pct'] as num?)?.toDouble();
    final sharpe = (m['sharpe_ratio']    as num?)?.toDouble();

    final bWin    = (baseline?['win_rate_pct']   as num?)?.toDouble();
    final bAvg    = (baseline?['avg_return_pct'] as num?)?.toDouble();
    final bDd     = (baseline?['max_drawdown_pct'] as num?)?.toDouble();
    final bSharpe = (baseline?['sharpe_ratio']   as num?)?.toDouble();

    return Container(
      decoration: kInnerCellDecoration(),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          _StatCell(value: n, label: 'Trades'),
          _StatCell(
            value:      win != null ? '${win.toStringAsFixed(1)}%' : '–',
            label:      'Win%',
            valueColor: baseline == null ? null : _compareColor(win, bWin),
          ),
          _StatCell(
            value:      avg != null ? '${avg >= 0 ? '+' : ''}${avg.toStringAsFixed(1)}%' : '–',
            label:      'Ø Rendite',
            valueColor: baseline == null ? null : _compareColor(avg, bAvg),
          ),
          _StatCell(
            value:      dd != null ? '${dd.toStringAsFixed(1)}%' : '–',
            label:      'MaxDD',
            // weniger negativ = besser → direkter Vergleich (−5 > −15 → grün)
            valueColor: baseline == null ? null : _compareColor(dd, bDd),
          ),
          _StatCell(
            value:      sharpe != null ? sharpe.toStringAsFixed(2) : '–',
            label:      'Sharpe',
            valueColor: baseline == null ? null : _compareColor(sharpe, bSharpe),
          ),
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
    final pnl   = (m['total_pnl_eur'] as num?)?.toDouble();
    if (pnl == null) return const SizedBox.shrink();
    final label = '${pnl >= 0 ? '+' : ''}€${pnl.toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        KestrelColors.innerBg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: KestrelColors.cardBorder),
      ),
      child: Text(label,
          style: const TextStyle(
            color:      KestrelColors.textPrimary,
            fontSize:   12,
            fontWeight: FontWeight.w700,
          )),
    );
  }
}

// ── Param Pill ─────────────────────────────────────────────

class ParamPill extends StatelessWidget {
  final String label;
  const ParamPill(this.label);

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

    final bWin    = (baseline['win_rate_pct']   as num).toDouble();
    final bAvg    = (baseline['avg_return_pct'] as num).toDouble();
    final bSharpe = (baseline['sharpe_ratio']   as num).toDouble();

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
    final roundedDelta = double.parse(delta.toStringAsFixed(1));
    final neutral = roundedDelta == 0.0;
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

// ── Kestrel Slider ─────────────────────────────────────────

class _KestrelSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final List<double> ticks;
  final double? baselineValue;
  final ValueChanged<double> onChanged;

  const _KestrelSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.ticks,
    required this.onChanged,
    this.baselineValue,
  });

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: value.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: KestrelColors.cardBg,
        title: Text(label,
            style: const TextStyle(
                color: KestrelColors.textPrimary, fontSize: 14)),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: KestrelColors.textPrimary),
          decoration: InputDecoration(
            hintText: '$min – $max',
            hintStyle:
                const TextStyle(color: KestrelColors.textHint),
            enabledBorder: const UnderlineInputBorder(
                borderSide:
                    BorderSide(color: KestrelColors.cardBorder)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: KestrelColors.gold)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen',
                style: TextStyle(color: KestrelColors.textGrey)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(
                  controller.text.replaceAll(',', '.'));
              if (v != null) onChanged(v.clamp(min, max));
              Navigator.pop(context);
            },
            child: const Text('OK',
                style: TextStyle(color: KestrelColors.gold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: kCardLabelStyle),
            GestureDetector(
              onTap: () => _showEditDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: KestrelColors.innerBg,
                  border: Border.all(color: KestrelColors.gold),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$unit${value.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color:      KestrelColors.gold,
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight:        5.0,
                activeTrackColor:   KestrelColors.gold,
                inactiveTrackColor: KestrelColors.cardBorder,
                thumbColor:         KestrelColors.gold,
                overlayColor:
                    KestrelColors.gold.withValues(alpha: 0.15),
                overlappingShapeStrokeColor: KestrelColors.appBarBg,
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 9, elevation: 0),
              ),
              child: Slider(
                value:     value,
                min:       min,
                max:       max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
            if (baselineValue != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BaselineMarkerPainter(
                      value: baselineValue!,
                      min:   min,
                      max:   max,
                      label: baselineValue!.toStringAsFixed(1),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ticks.map((t) => Column(
              children: [
                Container(
                    width: 1, height: 4,
                    color: KestrelColors.textHint),
                const SizedBox(height: 2),
                Text(
                  t % 1 == 0
                      ? t.toInt().toString()
                      : t.toStringAsFixed(1),
                  style: const TextStyle(
                      color: KestrelColors.textHint,
                      fontSize: 9),
                ),
              ],
            )).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Kestrel Range Slider ────────────────────────────────────

class _KestrelRangeSlider extends StatelessWidget {
  final String label;
  final double minValue;
  final double maxValue;
  final double min;
  final double max;
  final int divisions;
  final List<double> ticks;
  final double? baselineMin;
  final double? baselineMax;
  final ValueChanged<RangeValues> onChanged;

  const _KestrelRangeSlider({
    required this.label,
    required this.minValue,
    required this.maxValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.ticks,
    required this.onChanged,
    this.baselineMin,
    this.baselineMax,
  });

  void _showRangeEditDialog(BuildContext context, {required bool isMin}) {
    final current    = isMin ? minValue : maxValue;
    final controller = TextEditingController(
        text: current.toInt().toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: KestrelColors.cardBg,
        title: Text(
          isMin ? '$label – Minimum' : '$label – Maximum',
          style: const TextStyle(
              color: KestrelColors.textPrimary, fontSize: 14),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus:    true,
          style: const TextStyle(color: KestrelColors.textPrimary),
          decoration: InputDecoration(
            hintText:  '${min.toInt()} – ${max.toInt()}',
            hintStyle: const TextStyle(color: KestrelColors.textHint),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: KestrelColors.cardBorder)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: KestrelColors.gold)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen',
                style: TextStyle(color: KestrelColors.textGrey)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text);
              if (v != null) {
                final clamped = v.clamp(min, max);
                if (isMin) {
                  onChanged(RangeValues(
                      clamped.clamp(min, maxValue - 1), maxValue));
                } else {
                  onChanged(RangeValues(
                      minValue, clamped.clamp(minValue + 1, max)));
                }
              }
              Navigator.pop(context);
            },
            child: const Text('OK',
                style: TextStyle(color: KestrelColors.gold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: kCardLabelStyle),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showRangeEditDialog(context, isMin: true),
                  child: _RangeValueBadge(
                      value: minValue.toInt().toString()),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('–',
                      style: TextStyle(
                          color: KestrelColors.textHint,
                          fontSize: 10)),
                ),
                GestureDetector(
                  onTap: () => _showRangeEditDialog(context, isMin: false),
                  child: _RangeValueBadge(
                      value: maxValue.toInt().toString()),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight:        5.0,
                activeTrackColor:   KestrelColors.gold,
                inactiveTrackColor: KestrelColors.cardBorder,
                thumbColor:         KestrelColors.gold,
                overlayColor:
                    KestrelColors.gold.withValues(alpha: 0.15),
                rangeThumbShape: const RoundRangeSliderThumbShape(
                    enabledThumbRadius: 9, elevation: 0),
              ),
              child: RangeSlider(
                values:    RangeValues(minValue, maxValue),
                min:       min,
                max:       max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
            if (baselineMin != null && baselineMax != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _RangeBaselineMarkerPainter(
                      minValue: baselineMin!,
                      maxValue: baselineMax!,
                      min:      min,
                      max:      max,
                      minLabel: baselineMin!.toInt().toString(),
                      maxLabel: baselineMax!.toInt().toString(),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ticks.map((t) => Column(
              children: [
                Container(
                    width: 1, height: 4,
                    color: KestrelColors.textHint),
                const SizedBox(height: 2),
                Text(
                  t.toInt().toString(),
                  style: const TextStyle(
                      color: KestrelColors.textHint,
                      fontSize: 9),
                ),
              ],
            )).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Year Grid ──────────────────────────────────────────────

class _YearGrid extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  const _YearGrid({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    const years = [2022, 2023, 2024, 2025];
    return GridView.count(
      crossAxisCount:  2,
      shrinkWrap:      true,
      physics:         const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 6,
      mainAxisSpacing:  6,
      childAspectRatio: 3.1,
      children: years.map((year) {
        final active = selected.contains(year);
        return GestureDetector(
          onTap: () => onToggle(year),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color:        active ? KestrelColors.cardBg : KestrelColors.innerBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active ? KestrelColors.gold : KestrelColors.cardBorder,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width:  8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color:  active ? KestrelColors.gold : KestrelColors.cardBorder,
                    shape:  BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:  MainAxisAlignment.center,
                    children: [
                      Text(
                        '$year',
                        style: TextStyle(
                          color:      active
                              ? KestrelColors.gold
                              : KestrelColors.textDimmed,
                          fontSize:   14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _yearContext[year] ?? '',
                        style: TextStyle(
                          color:    active
                              ? KestrelColors.textDimmed
                              : KestrelColors.textHint,
                          fontSize: 9,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Range Value Badge ───────────────────────────────────────

class _RangeValueBadge extends StatelessWidget {
  final String value;
  const _RangeValueBadge({required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: KestrelColors.innerBg,
      border: Border.all(color: KestrelColors.gold),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(value,
        style: const TextStyle(
            color:      KestrelColors.gold,
            fontSize:   12,
            fontWeight: FontWeight.w700)),
  );
}

// ── Baseline Marker Painters ───────────────────────────────

class _BaselineMarkerPainter extends CustomPainter {
  final double value, min, max;
  final String label;
  const _BaselineMarkerPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const thumbPad  = 13.0;
    final trackWidth = size.width - thumbPad * 2;
    final x          = thumbPad + (value - min) / (max - min) * trackWidth;
    final centerY    = size.height / 2;

    final paint = Paint()
      ..color      = KestrelColors.gold
      ..strokeWidth = 3
      ..strokeCap  = StrokeCap.round;
    canvas.drawLine(Offset(x, centerY - 7), Offset(x, centerY + 7), paint);

    final tp = TextPainter(
      text: TextSpan(
        text:  label,
        style: const TextStyle(color: KestrelColors.gold, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, centerY + 9));
  }

  @override
  bool shouldRepaint(_BaselineMarkerPainter old) =>
      old.value != value || old.min != min || old.max != max;
}

class _RangeBaselineMarkerPainter extends CustomPainter {
  final double minValue, maxValue, min, max;
  final String minLabel, maxLabel;
  const _RangeBaselineMarkerPainter({
    required this.minValue,
    required this.maxValue,
    required this.min,
    required this.max,
    required this.minLabel,
    required this.maxLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const thumbPad   = 13.0;
    final trackWidth = size.width - thumbPad * 2;
    final centerY    = size.height / 2;

    final paint = Paint()
      ..color      = KestrelColors.gold
      ..strokeWidth = 3
      ..strokeCap  = StrokeCap.round;

    for (final (val, lbl) in [(minValue, minLabel), (maxValue, maxLabel)]) {
      final x = thumbPad + (val - min) / (max - min) * trackWidth;
      canvas.drawLine(Offset(x, centerY - 7), Offset(x, centerY + 7), paint);
      final tp = TextPainter(
        text: TextSpan(
          text:  lbl,
          style: const TextStyle(color: KestrelColors.gold, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, centerY + 9));
    }
  }

  @override
  bool shouldRepaint(_RangeBaselineMarkerPainter old) =>
      old.minValue != minValue || old.maxValue != maxValue;
}