import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';
import '../../widgets/info_sheet.dart';
import '../../widgets/offline_banner.dart';
import 'run_detail_screen.dart';

class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  CachedResult<Map<String, dynamic>>? _statusResult;
  CachedResult<List<dynamic>>?        _runsResult;
  Map<String, dynamic>?               _healthData;
  bool _loading      = true;
  bool _infoOpen     = false;
  bool _resumeLoading = false;

  String _appVersion     = '…';
  String _apiVersion     = '…';
  String _backendVersion = '…';

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
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      PackageInfo.fromPlatform(),
    ]);
    final prefs = results[0] as SharedPreferences;
    final info  = results[1] as PackageInfo;

    if (!mounted) return;
    setState(() {
      _appVersion     = info.version;
      _apiVersion     = prefs.getString('version_api')     ?? '…';
      _backendVersion = prefs.getString('version_backend') ?? '…';
    });

    try {
      final versions = await ApiService.getVersion();
      if (versions != null) {
        final api     = versions['api']     as String? ?? '–';
        final backend = versions['backend'] as String? ?? '–';
        await prefs.setString('version_api',     api);
        await prefs.setString('version_backend', backend);
        if (!mounted) return;
        setState(() {
          _apiVersion     = api;
          _backendVersion = backend;
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final statusFuture = ApiService.getSystemStatus();
      final runsFuture   = ApiService.getRuns(limit: 10);
      final healthFuture = ApiService.getSystemHealth();
      final status = await statusFuture;
      final runs   = await runsFuture;
      final health = await healthFuture;
      if (!mounted) return;
      setState(() {
        _statusResult = status;
        _runsResult   = runs;
        _healthData   = health;
        _loading      = false;
      });
      KestrelNav.of(context)?.setConnectionError(_isOffline);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      KestrelNav.of(context)?.setConnectionError(true);
    }
  }

  Future<void> _handleResume() async {
    setState(() => _resumeLoading = true);
    try {
      await ApiService.postResume();
      // Status neu laden – Pause-Card verschwindet
      await _load();
    } on ActionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: KestrelColors.red,
          duration: const Duration(seconds: 3),
        ));
      }
    } finally {
      if (mounted) setState(() => _resumeLoading = false);
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
                    _PauseCard(
                      status:         status,
                      resumeLoading:  _resumeLoading,
                      onResume:       _handleResume,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (status != null) ...[
                    _ServicesCard(status: status, health: _healthData),
                    const SizedBox(height: 8),
                  ],
                  if (runs != null && runs.isNotEmpty)
                    _RunLogCard(runs: runs),
                  const SizedBox(height: 8),
                  _VersionCard(
                    appVersion:     _appVersion,
                    apiVersion:     _apiVersion,
                    backendVersion: _backendVersion,
                  ),
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
          const Text('Status',
              style: TextStyle(color: KestrelColors.goldLight, fontSize: 16,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        ],
      ),
      actions: [
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
  final bool resumeLoading;
  final VoidCallback onResume;

  const _PauseCard({
    required this.status,
    required this.resumeLoading,
    required this.onResume,
  });

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
              style: const TextStyle(
                  color: KestrelColors.textPrimary, fontSize: 13)),
          if (since != null) ...[
            const SizedBox(height: 4),
            Text('seit ${_fmtDateTime(since)}',
                style: const TextStyle(
                    color: KestrelColors.textGrey, fontSize: 11)),
          ],
          const SizedBox(height: 14),
          // ── Checkliste ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0808),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: KestrelColors.redBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VOR RESUME PRÜFEN:',
                    style: TextStyle(color: KestrelColors.red, fontSize: 9,
                        fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                SizedBox(height: 6),
                _CheckItem('Marktlage im gleichen Zeitraum geprüft?'),
                _CheckItem('Strukturelle Fehler ausgeschlossen?'),
                _CheckItem('Datenbasierte Entscheidung für Wiederstart?'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Resume Button ────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: resumeLoading ? null : onResume,
              style: ElevatedButton.styleFrom(
                backgroundColor: KestrelColors.orange,
                disabledBackgroundColor: KestrelColors.orange.withOpacity(0.4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: resumeLoading
                  ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Pause aufheben',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  const _CheckItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('· ',
              style: TextStyle(color: KestrelColors.textDimmed, fontSize: 11)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: KestrelColors.textGrey, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ── Services Card ─────────────────────────────────────────────

class _ServicesCard extends StatelessWidget {
  final Map<String, dynamic> status;
  final Map<String, dynamic>? health;
  const _ServicesCard({required this.status, this.health});

  String _fmtTime(String? iso) {
    if (iso == null) return '–';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lastPing = status['last_ping_at'] as String?;
    final pingOk   = lastPing != null;

    // Service-Map aus /system/health aufbauen
    final svcList = (health?['services'] as List?)
        ?.map((e) => e as Map<String, dynamic>)
        .toList() ?? [];
    final svcMap = <String, Map<String, dynamic>>{
      for (final s in svcList) s['name'] as String: s,
    };

    String? svcStatus(String key) => svcMap[key]?['status'] as String?;
    String? svcDetail(String key) {
      final ms = (svcMap[key]?['latency_ms'] as num?)?.toInt();
      return ms != null ? '${ms}ms' : null;
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
          const Text('SERVICES', style: kCardLabelStyle),
          const SizedBox(height: 8),
          _ServiceRow(
            name:   'Pi',
            status: health != null ? svcStatus('pi')
                                   : (pingOk ? 'ok' : null),
            detail: health != null ? svcDetail('pi')
                                   : (pingOk ? _fmtTime(lastPing) : null),
          ),
          _ServiceRow(name: 'FMP',          status: svcStatus('fmp'),          detail: svcDetail('fmp')),
          _ServiceRow(name: 'Claude',       status: svcStatus('claude'),       detail: svcDetail('claude')),
          _ServiceRow(name: 'SEC EDGAR', status: svcStatus('edgar'), detail: svcDetail('edgar')),
          _ServiceRow(name: 'Healthchecks', status: svcStatus('healthchecks'), detail: svcDetail('healthchecks')),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final String  name;
  final String? status;   // 'ok' | 'degraded' | 'error' | null → grau
  final String? detail;   // z.B. '142ms' oder Uhrzeit
  const _ServiceRow({required this.name, this.status, this.detail});

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (status) {
      'ok'       => KestrelColors.green,
      'degraded' => KestrelColors.orange,
      'error'    => KestrelColors.red,
      _          => KestrelColors.textHint,
    };
    final statusText = status ?? '–';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name,
              style: const TextStyle(color: KestrelColors.textPrimary,
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(statusText,
                style: TextStyle(color: dotColor,
                    fontSize: 10, fontWeight: FontWeight.w600)),
            if (detail != null)
              Text(detail!,
                  style: const TextStyle(
                      color: KestrelColors.textHint, fontSize: 9)),
          ],
        ),
      ]),
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
          const Text('RUN-LOG', style: kCardLabelStyle),
          const SizedBox(height: 8),
          if (runs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Noch keine Runs',
                  style: TextStyle(
                      color: KestrelColors.textDimmed, fontSize: 13)),
            )
          else
            ...runs.take(10).toList().asMap().entries.map((entry) {
              final isLast = entry.key == runs.take(10).length - 1;
              final run = entry.value as Map<String, dynamic>;
              return Column(children: [
                _RunRow(run: run, fmtTime: _fmtRunTime),
                if (!isLast)
                  const Divider(height: 1, color: KestrelColors.cardBorder),
              ]);
            }),
        ],
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  final Map<String, dynamic> run;
  final String Function(String?) fmtTime;
  const _RunRow({required this.run, required this.fmtTime});

  @override
  Widget build(BuildContext context) {
    final runId  = run['run_id']           as String? ?? '';
    final count  = (run['shortlist_count'] as num?)?.toInt() ?? 0;
    final status = run['order_status']     as String? ?? 'skipped';
    final ticker = run['order_ticker']     as String?;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RunDetailScreen(run: run),
        ),
      ),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fmtTime(runId),
                  style: const TextStyle(color: KestrelColors.textPrimary,
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('$count ${count == 1 ? 'Kandidat' : 'Kandidaten'}',
                  style: const TextStyle(
                      color: KestrelColors.textGrey, fontSize: 10)),
            ],
          ),
          _OrderBadge(status: status, ticker: ticker),
        ],
      ),
    ));
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
      case 'bought':
        label  = ticker != null ? '$ticker gekauft' : 'gekauft';
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

// ── Version Card ──────────────────────────────────────────────

class _VersionCard extends StatelessWidget {
  final String appVersion;
  final String apiVersion;
  final String backendVersion;
  const _VersionCard({
    required this.appVersion,
    required this.apiVersion,
    required this.backendVersion,
  });

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
          const Text('APP-INFO', style: kCardLabelStyle),
          const SizedBox(height: 8),
          _VersionRow(label: 'App-Version',     value: appVersion),
          _VersionRow(label: 'API-Version',     value: apiVersion),
          _VersionRow(label: 'Backend-Version', value: backendVersion),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  final String label;
  final String value;
  const _VersionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: KestrelColors.textDimmed, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: KestrelColors.textGrey,
                  fontSize: 11,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────

const kCardLabelStyle = TextStyle(
  color: KestrelColors.gold,
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.8,
);