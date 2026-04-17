import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';
import '../positions/position_detail_screen.dart' hide fmtPrice, fmtPct;
import '../../widgets/info_sheet.dart';

class DashboardScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;

  const DashboardScreen({super.key, this.refreshNotifier});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  CachedResult<Map<String, dynamic>>? _result;
  bool _loading = true;
  bool _infoOpen = false;

  bool get _isOffline => _result?.isOffline ?? false;
  bool get _hasData   => _result != null;

  void _openInfo() {
    setState(() => _infoOpen = true);
    showKestrelInfoSheet(context).then((_) {
      if (mounted) setState(() => _infoOpen = false);
    });
  }

  @override
  void initState() {
    super.initState();
    widget.refreshNotifier?.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.getDashboard();
      if (!mounted) return;
      setState(() {
        _result  = result;
        _loading = false;
      });
      KestrelNav.of(context)?.setConnectionError(result.isOffline);
    } catch (e) {
      if (!mounted) return;
      // Kein Cache vorhanden – komplett leer
      setState(() {
        _result  = null;
        _loading = false;
      });
      KestrelNav.of(context)?.setConnectionError(true);
    }
  }

  AppBar _buildAppBar() {
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
            'Kestrel',
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
        IconButton(
          icon: const Icon(Icons.settings_outlined,
              color: KestrelColors.textGrey, size: 20),
          onPressed: () => KestrelNav.of(context)?.goToSettings(),
        ),
        InfoButton(active: _infoOpen, onTap: _openInfo),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: KestrelColors.cardBorder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: KestrelColors.gold))
          : !_hasData
          ? _buildNoDataState()
          : _buildBody(),
    );
  }

  // ── Kein Cache vorhanden (allererster Start ohne Verbindung) ──
  Widget _buildNoDataState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: KestrelColors.textHint, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Keine Verbindung',
              style: TextStyle(
                color: KestrelColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pi nicht erreichbar. Noch keine gecachten Daten vorhanden.',
              style: TextStyle(color: KestrelColors.textGrey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Erneut versuchen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: KestrelColors.gold,
                side: const BorderSide(color: KestrelColors.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hauptinhalt (online oder aus Cache) ──────────────────────
  Widget _buildBody() {
    final data         = _result!.data;
    final budget       = (data['budget']   as Map<String, dynamic>?) ?? {};
    final positions    = data['positions'] as List? ?? [];
    final drawdownData = (data['drawdown'] as Map<String, dynamic>?) ?? {};
    final latestRun    = data['last_run']  as Map<String, dynamic>?;
    final paused       = drawdownData['is_paused'] as bool? ?? false;

    final totalPnl = positions.fold<double>(
      0,
          (sum, p) =>
      sum +
          ((p as Map<String, dynamic>)['pnl_abs_eur'] as num? ?? 0)
              .toDouble(),
    );

    final drawdown   = (drawdownData['drawdown_pct']          as num?) ?? 0;
    final ddLimit    = (drawdownData['drawdown_limit_pct']    as num?) ?? 25;
    final consLosses = ((drawdownData['consecutive_losses']   as num?) ?? 0).toInt();
    final consLimit  = ((drawdownData['consecutive_loss_limit'] as num?) ?? 6).toInt();

    return RefreshIndicator(
      onRefresh: _load,
      color: KestrelColors.gold,
      backgroundColor: KestrelColors.cardBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          // ── Fehlerkachel (nur wenn offline + Cache) ──────────
          if (_isOffline) ...[
            _ErrorCard(
              cachedAt: _result!.cachedAt,
              onRetry: _load,
            ),
            const SizedBox(height: 8),
          ],

          // ── Normale Cards ─────────────────────────────────────
          if (paused)
            PauseBanner(
              drawdownPct: drawdownData['drawdown_pct'] as num?,
              reason:      drawdownData['pause_reason'] as String?,
            ),
          _BudgetHero(
            budget:   budget,
            totalPnl: positions.isEmpty ? null : totalPnl,
          ),
          const SizedBox(height: 6),
          _DrawdownCard(
            drawdown:   drawdown,
            limit:      ddLimit,
            consLosses: consLosses,
            consLimit:  consLimit,
            onTap:      () => KestrelNav.of(context)?.goToHistory(),
          ),
          const SizedBox(height: 8),
          _PositionsCard(positions: positions),
          const SizedBox(height: 8),
          if (latestRun != null) _LastRunStrip(latestRun: latestRun),
        ],
      ),
    );
  }
}

// ── Error Card (Dashboard-spezifisch) ────────────────────────

class _ErrorCard extends StatelessWidget {
  final DateTime? cachedAt;
  final VoidCallback onRetry;

  const _ErrorCard({this.cachedAt, required this.onRetry});

  String _formatAge() {
    if (cachedAt == null) return 'unbekannt';
    final d = DateTime.now().difference(cachedAt!);
    if (d.inMinutes < 1)  return 'wenigen Sekunden';
    if (d.inMinutes < 60) return '${d.inMinutes} Min.';
    if (d.inHours < 24)   return '${d.inHours} Std.';
    return '${d.inDays} Tag${d.inDays > 1 ? 'en' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1e0808),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF702020)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 2,
            decoration: const BoxDecoration(
              color: Color(0xFFe84040),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KEINE VERBINDUNG',
                  style: TextStyle(
                    color: Color(0xFFe84040),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pi nicht erreichbar. Daten von vor ${_formatAge()}',
                  style: const TextStyle(
                    color: KestrelColors.textGrey,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF702020)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Erneut versuchen',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFe84040),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Budget Hero ───────────────────────────────────────────────

class _BudgetHero extends StatelessWidget {
  final Map<String, dynamic> budget;
  final double? totalPnl;
  const _BudgetHero({required this.budget, this.totalPnl});

  @override
  Widget build(BuildContext context) {
    final total     = (budget['total_eur']     as num?) ?? 0;
    final available = (budget['available_eur'] as num?) ?? 0;
    final invested  = (budget['invested_eur']  as num?) ?? 0;
    final usedPct   = total > 0 ? (invested / total).clamp(0.0, 1.0) : 0.0;
    final pnlPos    = (totalPnl ?? 0) >= 0;

    return GoldTopCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BUDGET',
              style: TextStyle(
                color: KestrelColors.gold,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${total.toStringAsFixed(0)} €',
                  style: const TextStyle(
                    color: KestrelColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fmtPrice(invested),
                          style: const TextStyle(
                            color: KestrelColors.gold,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          'investiert',
                          style: TextStyle(
                              color: KestrelColors.textGrey, fontSize: 10),
                        ),
                      ],
                    ),
                    if (totalPnl != null) ...[
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            fmtPrice(totalPnl, showSign: true),
                            style: TextStyle(
                              color: pnlPos
                                  ? KestrelColors.green
                                  : KestrelColors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            'unrealisiert',
                            style: TextStyle(
                                color: KestrelColors.textGrey, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: LinearProgressIndicator(
                  value: usedPct.toDouble(),
                  backgroundColor: KestrelColors.screenBg,
                  valueColor:
                  const AlwaysStoppedAnimation<Color>(KestrelColors.gold),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(usedPct * 100).toStringAsFixed(0)}% investiert',
                  style: const TextStyle(
                      color: KestrelColors.textGrey, fontSize: 10),
                ),
                Text(
                  '${available.toStringAsFixed(2)} € verfügbar',
                  style: const TextStyle(
                      color: KestrelColors.textGrey, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drawdown Card ─────────────────────────────────────────────

class _DrawdownCard extends StatelessWidget {
  final num drawdown;
  final num limit;
  final int consLosses;
  final int consLimit;
  final VoidCallback? onTap;

  const _DrawdownCard({
    required this.drawdown,
    required this.limit,
    required this.consLosses,
    required this.consLimit,
    this.onTap,
  });

  Color _accentColor(double pct) {
    if (pct >= 0.9) return KestrelColors.red;
    if (pct >= 0.7) return KestrelColors.orange;
    return KestrelColors.green;
  }

  @override
  Widget build(BuildContext context) {
    final ddPct   = limit > 0
        ? (drawdown / limit).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final consPct = consLimit > 0
        ? (consLosses / consLimit).clamp(0.0, 1.0).toDouble()
        : 0.0;

    final ddColor   = _accentColor(ddPct);
    final consColor = _accentColor(consPct);

    // Card accent = higher risk of the two
    final Color cardAccent;
    if (ddPct >= 0.9 || consPct >= 0.9) {
      cardAccent = KestrelColors.red;
    } else if (ddPct >= 0.7 || consPct >= 0.7) {
      cardAccent = KestrelColors.orange;
    } else {
      cardAccent = KestrelColors.green;
    }

    final borderColor = cardAccent == KestrelColors.green
        ? KestrelColors.cardBorder
        : cardAccent.withOpacity(0.35);

    final consStatusText = consPct >= 0.9
        ? 'Gefahr'
        : consPct >= 0.7
        ? 'Warnung'
        : 'kein Risiko';

    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(
        children: [
          // ── Oberer Bereich: Ring + Info ───────────────────────
          Row(
            children: [
              // Ring
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: ddPct,
                      strokeWidth: 7,
                      backgroundColor: KestrelColors.screenBg,
                      valueColor: AlwaysStoppedAnimation<Color>(ddColor),
                      strokeCap: StrokeCap.round,
                    ),
                    Text(
                      '${drawdown.toStringAsFixed(1).replaceAll('.', ',')}%',
                      style: TextStyle(
                        color: ddColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Info-Spalte
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DRAWDOWN',
                      style: TextStyle(
                        color: KestrelColors.gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Hard Stop  ${limit.toStringAsFixed(1).replaceAll('.', ',')} %',
                      style: const TextStyle(
                        color: KestrelColors.textDimmed,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Auslastung  ${(ddPct * 100).toStringAsFixed(0)} %',
                      style: TextStyle(
                        color: ddColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Divider ───────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: KestrelColors.cardBorder),
          ),

          // ── Unterer Bereich: Konsek. Verluste ─────────────────
          Row(
            children: [
              // Label + Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KONSEK. VERLUSTE',
                      style: TextStyle(
                        color: KestrelColors.gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      consStatusText,
                      style: TextStyle(
                        color: consColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Punkte-Reihe
              Row(
                children: List.generate(consLimit, (i) {
                  final filled = i < consLosses;
                  return Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? consColor : KestrelColors.screenBg,
                        border: Border.all(
                          color: filled ? consColor : KestrelColors.cardBorder,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

// ── Positions Card ────────────────────────────────────────────

class _PositionsCard extends StatelessWidget {
  final List positions;
  const _PositionsCard({required this.positions});

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
          Text(
            'OFFENE POSITIONEN (${positions.length})',
            style: const TextStyle(
              color: KestrelColors.gold,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          if (positions.isEmpty)
            _buildEmptyState()
          else
            ...positions.map((p) {
              final pos = p as Map<String, dynamic>;
              return _PositionRow(
                position: pos,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PositionDetailScreen(ticker: pos['ticker'] as String),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: const [
            Icon(Icons.inbox_outlined,
                color: KestrelColors.textHint, size: 32),
            SizedBox(height: 8),
            Text(
              'Keine offenen Positionen',
              style: TextStyle(
                  color: KestrelColors.textGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Gekaufte Aktien erscheinen hier',
              style: TextStyle(color: KestrelColors.textHint, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Position Row ──────────────────────────────────────────────

class _PositionRow extends StatelessWidget {
  final Map<String, dynamic> position;
  final VoidCallback onTap;
  const _PositionRow({required this.position, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ticker  = position['ticker']      as String? ?? '–';
    final pnlPct  = (position['pnl_pct']    as num?)   ?? 0;
    final pnlAbs  = (position['pnl_abs_eur'] as num?)  ?? 0;
    final isPos   = pnlPct >= 0;

    // Traffic-light border color from signals
    final signals  = (position['signals'] as List?) ?? [];
    final severity = signals.isNotEmpty
        ? (signals.first as Map<String, dynamic>)['severity'] as String? ?? ''
        : '';
    final borderColor = switch (severity) {
      'HARD'  => KestrelColors.red,
      'WARN'  => KestrelColors.orange,
      _       => KestrelColors.green,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: KestrelColors.screenBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: KestrelColors.cardBorder),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Traffic-light border
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(8)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ticker,
                        style: const TextStyle(
                          color: KestrelColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${isPos ? '+' : ''}${pnlAbs.toStringAsFixed(2)} €',
                            style: const TextStyle(
                              color: KestrelColors.textGrey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.chevron_right,
                    color: KestrelColors.textHint, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Last Run Strip ────────────────────────────────────────────

class _LastRunStrip extends StatelessWidget {
  final Map<String, dynamic> latestRun;
  const _LastRunStrip({required this.latestRun});

  String _fmtTime(String runId) {
    if (runId.length < 13) return runId;
    final now   = DateTime.now();
    final year  = int.tryParse(runId.substring(0, 4)) ?? 0;
    final month = int.tryParse(runId.substring(4, 6)) ?? 0;
    final day   = int.tryParse(runId.substring(6, 8)) ?? 0;
    final hour  = runId.substring(9, 11);
    final min   = runId.substring(11, 13);
    final isToday =
        now.year == year && now.month == month && now.day == day;
    return isToday
        ? 'heute $hour:$min'
        : '$day.${month.toString().padLeft(2, '0')}. $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    final runId  = latestRun['run_id']          as String? ?? '';
    final count  = latestRun['shortlist_count'] as int?    ?? 0;
    final status = latestRun['order_status']    as String? ?? '–';

    if (runId.isEmpty) return const SizedBox.shrink();

    final statusStr = switch (status) {
      'filled'  => '✓ Kauf',
      'skipped' => '– kein Signal',
      _         => status,
    };

    return Container(
      decoration: BoxDecoration(
        color: KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KestrelColors.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Letzter Run: ${_fmtTime(runId)}',
            style: const TextStyle(
                color: KestrelColors.textGrey, fontSize: 10),
          ),
          Row(
            children: [
              Text(
                '$count Kandidat${count == 1 ? '' : 'en'}',
                style: const TextStyle(
                    color: KestrelColors.textDimmed, fontSize: 10),
              ),
              const Text(
                ' · ',
                style: TextStyle(
                    color: KestrelColors.textHint, fontSize: 10),
              ),
              Text(
                statusStr,
                style: TextStyle(
                  color: status == 'filled'
                      ? KestrelColors.green
                      : KestrelColors.textDimmed,
                  fontSize: 10,
                  fontWeight: status == 'filled'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}