import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';

class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  Map<String, dynamic>? _status;
  List<dynamic>? _runs;
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
        ApiService.getSystemStatus(),
        ApiService.getRuns(),
      ]);
      setState(() {
        _status  = results[0] as Map<String, dynamic>;
        _runs    = results[1] as List;
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

    final paused = _status!['paused'] as bool;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: _buildAppBar(paused),
      body: RefreshIndicator(
        onRefresh: _load,
        color: KestrelColors.gold,
        backgroundColor: KestrelColors.cardBg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          children: [
            if (paused) ...[
              _PauseCard(status: _status!),
              const SizedBox(height: 8),
            ],
            _ServicesCard(status: _status!),
            const SizedBox(height: 8),
            _RunLogCard(runs: _runs!),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool paused) {
    return AppBar(
      backgroundColor: KestrelColors.appBarBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 13,
      title: Row(
        children: [
          KestrelLogo(size: 26),
          const SizedBox(width: 8),
          const Text('System',
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: paused ? KestrelColors.redBg : KestrelColors.greenBg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: paused ? KestrelColors.redBorder : KestrelColors.greenBorder,
              ),
            ),
            child: Text(
              paused ? 'Pausiert' : 'Aktiv',
              style: TextStyle(
                  color: paused ? KestrelColors.red : KestrelColors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: KestrelColors.cardBorder),
      ),
    );
  }
}

// ── Pause Card ────────────────────────────────────────────────

class _PauseCard extends StatelessWidget {
  final Map<String, dynamic> status;
  const _PauseCard({required this.status});

  String _fmtDateTime(String? iso) {
    if (iso == null || iso.length < 16) return '–';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}, '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final reason = status['pause_reason'] as String? ?? '–';
    final since  = status['pause_since']  as String?;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E0808),
          border: Border.all(color: KestrelColors.redBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 2, color: KestrelColors.red),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SYSTEM PAUSIERT',
                      style: TextStyle(
                          color: KestrelColors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6)),
                  const SizedBox(height: 4),
                  Text(reason,
                      style: const TextStyle(
                          color: KestrelColors.textGrey, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('seit ${_fmtDateTime(since)}',
                      style: const TextStyle(
                          color: KestrelColors.textDimmed, fontSize: 10)),
                  const SizedBox(height: 12),
                  // Resume-Button — V1 read-only, visuell vorhanden
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: KestrelColors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Resume',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Services Card ─────────────────────────────────────────────

class _ServicesCard extends StatelessWidget {
  final Map<String, dynamic> status;
  const _ServicesCard({required this.status});

  String _fmtTime(String? iso) {
    if (iso == null) return '–';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lastPing      = status['last_ping_at'] as String?;
    final drawdown      = status['drawdown_pct'] as num;
    final threshold     = status['drawdown_threshold_pct'] as num;
    final consLosses    = (status['consecutive_losses']    as num).toInt();
    final consLimit     = (status['consecutive_loss_limit'] as num).toInt();

    // Services werden aus SystemStatus abgeleitet:
    // Pi-Healthcheck aus last_ping_at, Rest muss von /system/health kommen (V2).
    // V1: nur Pi-Ping anzeigen, andere als "–" bis Endpoint verfügbar.
    final pingTime = _fmtTime(lastPing);
    final pingOk   = lastPing != null;

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
          const Text('SYSTEM-STATUS', style: kCardLabelStyle),
          const SizedBox(height: 10),

          // Drawdown + Verluste
          Row(
            children: [
              Expanded(child: _StatRow(
                label: 'Drawdown',
                value: '${drawdown.toStringAsFixed(1).replaceAll('.', ',')} % / '
                    '${threshold.toStringAsFixed(0)} %',
                valueColor: drawdown >= threshold * 0.8
                    ? KestrelColors.orange : KestrelColors.textPrimary,
              )),
              Expanded(child: _StatRow(
                label: 'Konsek. Verluste',
                value: '$consLosses / $consLimit',
                valueColor: consLosses >= consLimit * 0.8
                    ? KestrelColors.orange : KestrelColors.textPrimary,
              )),
            ],
          ),
          const Divider(height: 16, color: KestrelColors.cardBorder),

          // Services
          const Text('SERVICES', style: kCardLabelStyle),
          const SizedBox(height: 8),
          _ServiceRow(
            name: 'Pi',
            ok: pingOk,
            detail: pingOk ? pingTime : null,
          ),
          _ServiceRow(name: 'FMP',          ok: null),
          _ServiceRow(name: 'Claude',       ok: null),
          _ServiceRow(name: 'SEC EDGAR',    ok: null),
          _ServiceRow(name: 'Healthchecks', ok: pingOk, detail: pingOk ? pingTime : null),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Service-Details verfügbar ab /system/health (V2)',
              style: const TextStyle(
                  color: KestrelColors.textHint, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: KestrelColors.textGrey, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: valueColor ?? KestrelColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final String name;
  final bool? ok;       // null = unbekannt (kein Endpoint in V1)
  final String? detail;
  const _ServiceRow({required this.name, required this.ok, this.detail});

  @override
  Widget build(BuildContext context) {
    final dotColor = ok == null
        ? KestrelColors.textHint
        : ok! ? KestrelColors.green : KestrelColors.red;

    final statusText = ok == null
        ? '–'
        : ok! ? 'ok' : 'error';

    final statusColor = ok == null
        ? KestrelColors.textHint
        : ok! ? KestrelColors.green : KestrelColors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: KestrelColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(statusText,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
              if (detail != null)
                Text(detail!,
                    style: const TextStyle(
                        color: KestrelColors.textHint, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Run Log Card ──────────────────────────────────────────────

class _RunLogCard extends StatelessWidget {
  final List runs;
  const _RunLogCard({required this.runs});

  String _fmtRunTime(String runId) {
    if (runId.length < 13) return runId;
    final date = runId.substring(0, 8);
    final time = '${runId.substring(9, 11)}:${runId.substring(11, 13)}';
    return '${date.substring(6, 8)}.${date.substring(4, 6)}. $time';
  }

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
          const Text('RUN-LOG', style: kCardLabelStyle),
          const SizedBox(height: 8),
          if (runs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Noch keine Runs',
                  style: TextStyle(color: KestrelColors.textDimmed, fontSize: 13)),
            )
          else
            ...runs.take(10).toList().asMap().entries.map((entry) {
              final isLast = entry.key == runs.take(10).length - 1;
              final run = entry.value as Map<String, dynamic>;
              return Column(
                children: [
                  _RunRow(run: run, fmtTime: _fmtRunTime),
                  if (!isLast)
                    const Divider(height: 1, color: KestrelColors.cardBorder),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  final Map<String, dynamic> run;
  final String Function(String) fmtTime;
  const _RunRow({required this.run, required this.fmtTime});

  @override
  Widget build(BuildContext context) {
    final runId   = run['run_id']          as String;
    final count   = (run['shortlist_count'] as num).toInt();
    final status  = run['order_status']    as String;
    final ticker  = run['order_ticker']    as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fmtTime(runId),
                  style: const TextStyle(
                      color: KestrelColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('$count ${count == 1 ? 'Kandidat' : 'Kandidaten'}',
                  style: const TextStyle(
                      color: KestrelColors.textGrey, fontSize: 10)),
            ],
          ),
          _OrderBadge(status: status, ticker: ticker),
        ],
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  final String status;
  final String? ticker;
  const _OrderBadge({required this.status, this.ticker});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color bg;
    final Color border;
    final String label;

    switch (status) {
      case 'filled':
        label  = ticker != null ? '$ticker filled' : 'filled';
        color  = KestrelColors.green;
        bg     = KestrelColors.greenBg;
        border = KestrelColors.greenBorder;
      case 'pending':
        label  = ticker != null ? '$ticker pending' : 'pending';
        color  = KestrelColors.gold;
        bg     = KestrelColors.goldBg;
        border = KestrelColors.goldBorder;
      default:
        label  = 'skipped';
        color  = KestrelColors.textDimmed;
        bg     = KestrelColors.screenBg;
        border = KestrelColors.cardBorder;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}