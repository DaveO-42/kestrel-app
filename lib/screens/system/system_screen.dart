import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';
import '../../widgets/info_sheet.dart';
import '../../widgets/offline_banner.dart';

class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  CachedResult<Map<String, dynamic>>? _statusResult;
  CachedResult<List<dynamic>>?        _runsResult;
  bool _loading = true;
  bool _infoOpen = false;

  bool get _isOffline => _statusResult?.isOffline ?? false;
  DateTime? get _cachedAt => _statusResult?.cachedAt;

  void _openInfo() {
    setState(() => _infoOpen = true);
    showKestrelInfoSheet(context).then((_) {
      if (mounted) setState(() => _infoOpen = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final statusFuture = ApiService.getSystemStatus();
      final runsFuture   = ApiService.getRuns(limit: 10);
      final status = await statusFuture;
      final runs   = await runsFuture;
      if (!mounted) return;
      setState(() {
        _statusResult = status;
        _runsResult   = runs;
        _loading = false;
      });
      KestrelNav.of(context)?.setConnectionError(_isOffline);
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
        body: Center(child: CircularProgressIndicator(color: KestrelColors.gold)),
      );
    }

    final status = _statusResult?.data;
    final runs   = _runsResult?.data;
    final paused = status?['is_paused'] as bool? ?? false;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: _buildAppBar(paused),
      body: Column(
        children: [
          if (_isOffline)
            OfflineBanner(cachedAt: _cachedAt),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: KestrelColors.gold,
              backgroundColor: KestrelColors.cardBg,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                children: [
                  if (paused && status != null) ...[
                    _PauseCard(status: status),
                    const SizedBox(height: 8),
                  ],
                  if (status != null) ...[
                    _DrawdownCard(status: status),
                    const SizedBox(height: 8),
                  ],
                  if (runs != null && runs.isNotEmpty)
                    _RunLogCard(runs: runs),
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
          const Text('System',
              style: TextStyle(color: KestrelColors.goldLight, fontSize: 16,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
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
                  color: paused ? KestrelColors.redBorder : KestrelColors.greenBorder),
            ),
            child: Text(
              paused ? 'Pausiert' : 'Aktiv',
              style: TextStyle(
                  color: paused ? KestrelColors.red : KestrelColors.green,
                  fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        InfoButton(active: _infoOpen, onTap: _openInfo),
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
    final since  = status['paused_at']    as String?;

    return Container(
      decoration: BoxDecoration(
        color: KestrelColors.redBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KestrelColors.redBorder),
      ),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SYSTEM PAUSIERT',
              style: TextStyle(color: KestrelColors.red, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Text(reason,
              style: const TextStyle(color: KestrelColors.textPrimary, fontSize: 13)),
          if (since != null) ...[
            const SizedBox(height: 4),
            Text('seit ${_fmtDateTime(since)}',
                style: const TextStyle(color: KestrelColors.textGrey, fontSize: 11)),
          ],
          const SizedBox(height: 12),
          const Text('Resume via Telegram: /resume',
              style: TextStyle(color: KestrelColors.textGrey, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Drawdown Card ─────────────────────────────────────────────

class _DrawdownCard extends StatelessWidget {
  final Map<String, dynamic> status;
  const _DrawdownCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final drawdown = (status['drawdown_pct']       as num?) ?? 0;
    final limit    = (status['drawdown_limit_pct'] as num?) ?? 25;
    final pct      = limit > 0 ? (drawdown / limit).clamp(0.0, 1.0) : 0.0;
    final isWarn   = pct >= 0.7;
    final barColor = isWarn ? KestrelColors.orange : KestrelColors.green;

    return Container(
      decoration: BoxDecoration(
        color: KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KestrelColors.cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DRAWDOWN',
              style: TextStyle(color: KestrelColors.gold, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${drawdown.toStringAsFixed(1).replaceAll('.', ',')} %',
                style: TextStyle(
                    color: isWarn ? KestrelColors.orange : KestrelColors.textPrimary,
                    fontSize: 24, fontWeight: FontWeight.w700),
              ),
              Text('Limit ${limit.toStringAsFixed(0)} %',
                  style: const TextStyle(color: KestrelColors.textGrey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: LinearProgressIndicator(
                value: pct.toDouble(),
                backgroundColor: KestrelColors.screenBg,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
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

  String _fmtRunTime(String? runId) {
    if (runId == null || runId.length < 13) return runId ?? '–';
    final now   = DateTime.now();
    final year  = int.tryParse(runId.substring(0, 4)) ?? 0;
    final month = int.tryParse(runId.substring(4, 6)) ?? 0;
    final day   = int.tryParse(runId.substring(6, 8)) ?? 0;
    final hour  = runId.substring(9, 11);
    final min   = runId.substring(11, 13);
    final isToday = now.year == year && now.month == month && now.day == day;
    return isToday
        ? 'heute $hour:$min'
        : '$day.${month.toString().padLeft(2, '0')}. $hour:$min';
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
          const Text('RUN-LOG',
              style: TextStyle(color: KestrelColors.gold, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          ...runs.map((r) {
            final run    = r as Map<String, dynamic>;
            final runId  = run['run_id']          as String? ?? '';
            final count  = run['shortlist_count'] as int?    ?? 0;
            final status = run['order_status']    as String? ?? '–';

            final statusColor = switch (status) {
              'filled'  => KestrelColors.green,
              'skipped' => KestrelColors.textDimmed,
              _         => KestrelColors.textGrey,
            };
            final statusStr = switch (status) {
              'filled'  => '✓ Kauf',
              'skipped' => '– kein Signal',
              _         => status,
            };

            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmtRunTime(runId),
                      style: const TextStyle(
                          color: KestrelColors.textGrey, fontSize: 11)),
                  Row(children: [
                    Text('$count Kand.',
                        style: const TextStyle(
                            color: KestrelColors.textDimmed, fontSize: 11)),
                    const Text(' · ',
                        style: TextStyle(
                            color: KestrelColors.textHint, fontSize: 11)),
                    Text(statusStr,
                        style: TextStyle(color: statusColor, fontSize: 11,
                            fontWeight: status == 'filled'
                                ? FontWeight.w600 : FontWeight.normal)),
                  ]),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}