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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getSystemStatus(),
        ApiService.getRuns(limit: 10),
      ]);
      if (!mounted) return;
      setState(() {
        _status  = results[0] as Map<String, dynamic>;
        _runs    = results[1] as List<dynamic>;
        _loading = false;
      });
      // System-Screen ist der Ziel-Screen für Verbindungsfehler —
      // wenn er erfolgreich lädt, Fehler zurücksetzen
      KestrelNav.of(context)?.setConnectionError(false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      KestrelNav.of(context)?.setConnectionError(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: KestrelColors.screenBg,
        body: Center(
            child: CircularProgressIndicator(color: KestrelColors.gold)),
      );
    }

    final connError = KestrelNav.of(context)?.connectionError ?? false;
    final paused    = _status?['paused'] as bool? ?? false;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: _buildAppBar(paused),
      body: Column(
        children: [
          // System-Screen zeigt ErrorBanner nur wenn er selbst nicht laden konnte
          if (connError && _status == null) const ErrorBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: KestrelColors.gold,
              backgroundColor: KestrelColors.cardBg,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                children: [
                  if (paused && _status != null) ...[
                    _PauseCard(status: _status!),
                    const SizedBox(height: 8),
                  ],
                  if (_status != null) ...[
                    _ServicesCard(status: _status!),
                    const SizedBox(height: 8),
                  ],
                  if (_runs != null && _runs!.isNotEmpty)
                    _RunLogCard(runs: _runs!),
                ],
              ),
            ),
          ),
        ],
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
          const Text(
            'System',
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
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: paused ? KestrelColors.redBg : KestrelColors.greenBg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: paused
                    ? KestrelColors.redBorder
                    : KestrelColors.greenBorder,
              ),
            ),
            child: Text(
              paused ? 'Pausiert' : 'Aktiv',
              style: TextStyle(
                color: paused ? KestrelColors.red : KestrelColors.green,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh,
              color: KestrelColors.textDimmed, size: 20),
          onPressed: _load,
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
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year}, '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
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
                  const Text(
                    'SYSTEM PAUSIERT',
                    style: TextStyle(
                      color: KestrelColors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reason,
                    style: const TextStyle(
                        color: KestrelColors.textGrey, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'seit ${_fmtDateTime(since)}',
                    style: const TextStyle(
                        color: KestrelColors.textDimmed, fontSize: 10),
                  ),
                  const SizedBox(height: 12),
                  // Resume — V1 read-only, V2 funktional
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: KestrelColors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Resume',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
    if (iso == null || iso.length < 19) return '–';
    return iso.substring(11, 19);
  }

  @override
  Widget build(BuildContext context) {
    final lastPing = status['last_ping_at'] as String?;

    // V1: Pi + Healthchecks aus system/status, Rest placeholder bis /system/health in V2
    final services = [
      {'name': 'Pi',           'status': 'ok',      'ts': _fmtTime(lastPing), 'latency': null},
      {'name': 'FMP',          'status': 'unknown',  'ts': '–',                'latency': null},
      {'name': 'Claude',       'status': 'unknown',  'ts': '–',                'latency': null},
      {'name': 'SEC EDGAR',    'status': 'unknown',  'ts': '–',                'latency': null},
      {'name': 'Healthchecks', 'status': 'ok',       'ts': _fmtTime(lastPing), 'latency': null},
    ];

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
          const Text('SERVICES', style: kCardLabelStyle),
          const SizedBox(height: 8),
          ...services.map((s) => _ServiceRow(service: s)),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final Map<String, dynamic> service;
  const _ServiceRow({required this.service});

  Color _dotColor(String status) => switch (status) {
    'ok'       => KestrelColors.green,
    'degraded' => KestrelColors.orange,
    'error'    => KestrelColors.red,
    _          => KestrelColors.textHint,
  };

  @override
  Widget build(BuildContext context) {
    final status  = service['status']  as String;
    final name    = service['name']    as String;
    final ts      = service['ts']      as String;
    final latency = service['latency'] as int?;
    final dotColor = _dotColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: KestrelColors.textPrimary,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            status == 'unknown'
                ? '–'
                : latency != null
                ? '$status · ${latency}ms'
                : status,
            style: TextStyle(color: dotColor, fontSize: 10),
          ),
          const SizedBox(width: 8),
          Text(
            ts,
            style: const TextStyle(
                color: KestrelColors.textHint, fontSize: 10),
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
    final date = '${runId.substring(6, 8)}.${runId.substring(4, 6)}.';
    final time = '${runId.substring(9, 11)}:${runId.substring(11, 13)}';
    return '$date $time';
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
          ...runs.take(5).map((run) {
            final r      = run as Map<String, dynamic>;
            final runId  = r['run_id']       as String? ?? '';
            final count  = r['shortlist_count'] as int? ?? 0;
            final status = r['order_status'] as String? ?? '–';
            final ticker = r['order_ticker'] as String?;
            return _RunRow(
              time:   _fmtRunTime(runId),
              count:  count,
              status: status,
              ticker: ticker,
            );
          }),
        ],
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  final String time;
  final int count;
  final String status;
  final String? ticker;
  const _RunRow({
    required this.time,
    required this.count,
    required this.status,
    this.ticker,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'filled'  => ('${ticker ?? ''} filled', KestrelColors.green),
      'pending' => ('pending',                KestrelColors.gold),
      'skipped' => ('skipped',                KestrelColors.textDimmed),
      _         => (status,                   KestrelColors.textHint),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    color: KestrelColors.textPrimary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '$count Kandidat${count == 1 ? '' : 'en'}',
                  style: const TextStyle(
                      color: KestrelColors.textDimmed, fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: KestrelColors.screenBg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: KestrelColors.cardBorder),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}