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

  // ── Parameter ─────────────────────────────────────────────
  double _atrMultiplier = 2.0;
  double _rsiMin        = 50;
  double _rsiMax        = 70;
  double _minPerf       = 3.0;
  final Set<int> _years = {2022, 2023, 2024};

  // ── Job State ──────────────────────────────────────────────
  String?               _jobId;
  String                _jobStatus  = '';
  String                _jobMessage = '';
  int                   _jobCurrent = 0;
  int                   _jobTotal   = 3;
  Map<String, dynamic>? _result;
  String?               _error;
  bool                  _running    = false;
  Timer?                _pollTimer;

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
    _hoverAnim = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Backtest starten ───────────────────────────────────────
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
      _startPolling();
    } catch (e) {
      setState(() {
        _running = false;
        _error   = e.toString();
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_jobId == null) return;
    try {
      final status = await ApiService.getSandboxStatus(_jobId!);
      final s = status['status'] as String? ?? '';
      setState(() {
        _jobStatus  = s;
        _jobMessage = status['message'] as String? ?? '';
        _jobCurrent = (status['current'] as num?)?.toInt() ?? 0;
        _jobTotal   = (status['total']   as num?)?.toInt() ?? 3;
      });
      if (s == 'done') {
        _pollTimer?.cancel();
        setState(() {
          _running = false;
          _result  = status['result'] as Map<String, dynamic>?;
        });
      } else if (s == 'cancelled') {
        _pollTimer?.cancel();
        setState(() { _running = false; });
      } else if (s == 'error') {
        _pollTimer?.cancel();
        setState(() {
          _running = false;
          _error   = status['error'] as String? ?? 'Unbekannter Fehler';
        });
      }
    } catch (_) {}
  }

  Future<void> _cancelRun() async {
    if (_jobId == null) return;
    _pollTimer?.cancel();
    try {
      await ApiService.postSandboxCancel(_jobId!);
    } catch (_) {}
    setState(() { _running = false; });
  }

  void _reset() {
    _pollTimer?.cancel();
    setState(() {
      _running    = false;
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
    return _running
        ? _buildHoverScreen()
        : _result != null
        ? _buildResults()
        : _buildParams();
  }

  // ── Parameter-Screen ───────────────────────────────────────
  Widget _buildParams() {
    final canRun = _years.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) _ErrorCard(message: _error!, onDismiss: _reset),
          _SandboxCard(
            title: 'ATR-Multiplikator (Stop)',
            child: _SliderRow(
              value:     _atrMultiplier,
              min:       1.0,
              max:       4.0,
              divisions: 12,
              label:     _atrMultiplier.toStringAsFixed(1),
              onChanged: (v) => setState(() => _atrMultiplier = v),
              baseline:  2.0,
            ),
          ),
          const SizedBox(height: 12),
          _SandboxCard(
            title: 'RSI-Bereich',
            child: Column(
              children: [
                _SliderRow(
                  label:     'Min ${_rsiMin.round()}',
                  value:     _rsiMin,
                  min:       30,
                  max:       65,
                  divisions: 35,
                  onChanged: (v) => setState(() {
                    _rsiMin = v;
                    if (_rsiMin >= _rsiMax) _rsiMax = _rsiMin + 5;
                  }),
                  baseline: 50,
                ),
                _SliderRow(
                  label:     'Max ${_rsiMax.round()}',
                  value:     _rsiMax,
                  min:       55,
                  max:       85,
                  divisions: 30,
                  onChanged: (v) => setState(() {
                    _rsiMax = v;
                    if (_rsiMax <= _rsiMin) _rsiMin = _rsiMax - 5;
                  }),
                  baseline: 70,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SandboxCard(
            title: 'Min. Performance nach Beat (%)',
            child: _SliderRow(
              value:     _minPerf,
              min:       0.0,
              max:       10.0,
              divisions: 20,
              label:     '+${_minPerf.toStringAsFixed(1)}%',
              onChanged: (v) => setState(() => _minPerf = v),
              baseline:  3.0,
            ),
          ),
          const SizedBox(height: 12),
          _SandboxCard(
            title: 'Zeitraum',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [2022, 2023, 2024].map((y) {
                final active = _years.contains(y);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (active && _years.length > 1) {
                      _years.remove(y);
                    } else {
                      _years.add(y);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? KestrelColors.gold
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active
                            ? KestrelColors.gold
                            : KestrelColors.cardBorder,
                      ),
                    ),
                    child: Text(
                      '$y',
                      style: TextStyle(
                        color: active
                            ? KestrelColors.appBarBg   // dunkel auf gold
                            : KestrelColors.textGrey,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: canRun ? _startRun : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: canRun
                    ? KestrelColors.gold
                    : KestrelColors.cardBorder,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                'Backtest starten',
                style: TextStyle(
                  color: canRun
                      ? KestrelColors.appBarBg   // dunkel auf gold
                      : KestrelColors.textGrey,
                  fontWeight: FontWeight.bold,
                  fontSize:   16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hover-Screen ───────────────────────────────────────────
  Widget _buildHoverScreen() {
    final pct        = _jobTotal > 0 ? _jobCurrent / _jobTotal : 0.0;
    final sortedYears = _years.toList()..sort();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _hoverAnim,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _hoverAnim.value),
                child: const KestrelLogo(size: 100),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _jobMessage,
              style: const TextStyle(
                color:    KestrelColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:           pct,
                minHeight:       6,
                backgroundColor: KestrelColors.cardBorder,
                valueColor: const AlwaysStoppedAnimation(KestrelColors.gold),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: sortedYears.map((y) {
                final idx    = sortedYears.indexOf(y);
                final done   = idx < _jobCurrent;
                final active = idx == _jobCurrent && _running;
                return Text(
                  done   ? '$y ✓'
                      : active ? '$y…'
                      : '$y',
                  style: TextStyle(
                    color: done
                        ? KestrelColors.green
                        : active
                        ? KestrelColors.gold
                        : KestrelColors.textGrey,
                    fontSize:   13,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _cancelRun,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color:        Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: KestrelColors.cardBorder),
                ),
                child: const Text(
                  'Abbrechen',
                  style: TextStyle(
                    color:    KestrelColors.textGrey,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ergebnis-Screen ────────────────────────────────────────
  Widget _buildResults() {
    final yearResults = _result?['year_results'] as Map<String, dynamic>? ?? {};
    final total       = _result?['total']        as Map<String, dynamic>? ?? {};
    final params      = _result?['params']        as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ParamsChip(params: params),
          const SizedBox(height: 16),
          ...(yearResults.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
              .map((e) => _MetricsCard(
            year:    e.key,
            metrics: e.value as Map<String, dynamic>,
          )),
          if (yearResults.length > 1)
            _MetricsCard(year: 'Gesamt', metrics: total, isTotal: true),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _reset,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color:        Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border:       Border.all(color: KestrelColors.cardBorder),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Neue Konfiguration',
                style: TextStyle(color: KestrelColors.textGrey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hilfs-Widgets ──────────────────────────────────────────────

class _SandboxCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SandboxCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color:        KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: KestrelColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color:   KestrelColors.textGrey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final double value;
  final double min, max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;
  final double baseline;

  const _SliderRow({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
    required this.baseline,
  });

  @override
  Widget build(BuildContext context) {
    final changed = (value - baseline).abs() > 0.05;
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: changed
                  ? KestrelColors.gold
                  : KestrelColors.textPrimary,
              fontWeight: changed ? FontWeight.bold : FontWeight.normal,
              fontSize:   14,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor:   KestrelColors.gold,
              inactiveTrackColor: KestrelColors.cardBorder,
              thumbColor:         KestrelColors.gold,
              overlayColor:       KestrelColors.gold.withOpacity(0.2),
              trackHeight:        3,
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

class _MetricsCard extends StatelessWidget {
  final String year;
  final Map<String, dynamic> metrics;
  final bool isTotal;
  const _MetricsCard({
    required this.year,
    required this.metrics,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final err      = metrics['error'] as String?;
    final pnl      = (metrics['total_pnl_eur'] as num?)?.toDouble() ?? 0;
    final positive = pnl >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTotal
              ? KestrelColors.goldBorder
              : KestrelColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                year,
                style: TextStyle(
                  color: isTotal
                      ? KestrelColors.gold
                      : KestrelColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize:   15,
                ),
              ),
              if (err == null)
                Text(
                  '${positive ? '+' : ''}€${pnl.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: positive
                        ? KestrelColors.green
                        : KestrelColors.red,
                    fontWeight: FontWeight.bold,
                    fontSize:   15,
                  ),
                ),
            ],
          ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                err,
                style: const TextStyle(
                  color:    KestrelColors.textGrey,
                  fontSize: 13,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 10),
            _MetricsGrid(metrics: metrics),
          ],
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final Map<String, dynamic> metrics;
  const _MetricsGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final n      = metrics['trades_total'] ?? 0;
    final win    = metrics['win_rate_pct'] ?? 0;
    final avg    = (metrics['avg_return_pct'] as num?)?.toDouble() ?? 0;
    final dd     = (metrics['max_drawdown_pct'] as num?)?.toDouble() ?? 0;
    final sharpe = metrics['sharpe_ratio'] ?? 0;

    return Row(
      children: [
        _Stat('Trades', '$n'),
        _Stat('Win%',   '$win%'),
        _Stat('Ø Ret',  '${avg >= 0 ? '+' : ''}${avg.toStringAsFixed(1)}%'),
        _Stat('MaxDD',  '${dd.toStringAsFixed(1)}%'),
        _Stat('Sharpe', '$sharpe'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color:    KestrelColors.textGrey,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color:      KestrelColors.textPrimary,
            fontSize:   13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _ParamsChip extends StatelessWidget {
  final Map<String, dynamic> params;
  const _ParamsChip({required this.params});

  @override
  Widget build(BuildContext context) {
    final atr    = params['atr_multiplier'];
    final rsiMin = params['rsi_min'];
    final rsiMax = params['rsi_max'];
    final perf   = params['min_perf_pct'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: KestrelColors.cardBorder),
      ),
      child: Text(
        'ATR ×$atr  ·  RSI $rsiMin–$rsiMax  ·  Perf >$perf%',
        style: const TextStyle(
          color:    KestrelColors.textGrey,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorCard({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color:        KestrelColors.redBg,
      borderRadius: BorderRadius.circular(8),
      border:       Border.all(color: KestrelColors.redBorder),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: KestrelColors.red, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: KestrelColors.red, fontSize: 13),
          ),
        ),
        GestureDetector(
          onTap: onDismiss,
          child: const Icon(Icons.close, color: KestrelColors.red, size: 16),
        ),
      ],
    ),
  );
}