import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';
import '../positions/position_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _connError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading   = true;
      _connError = false;
    });
    try {
      final data = await ApiService.getDashboard();
      if (!mounted) return;
      setState(() {
        _data      = data;
        _loading   = false;
        _connError = false;
      });
      KestrelNav.of(context)?.setConnectionError(false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading   = false;
        _connError = true;
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
          icon: const Icon(Icons.refresh, color: KestrelColors.textGrey, size: 20),
          onPressed: _load,
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: KestrelColors.textGrey, size: 20),
          onPressed: () => KestrelNav.of(context)?.goToSettings(),
        ),
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
          : _connError
          ? _buildErrorState()
          : _buildBody(),
    );
  }

  Widget _buildErrorState() {
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
              'Pi nicht erreichbar oder API nicht gestartet',
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

  Widget _buildBody() {
    final budget       = _data!['budget']    as Map<String, dynamic>;
    final positions    = _data!['positions'] as List? ?? [];
    final drawdownData = _data!['drawdown']  as Map<String, dynamic>;
    final latestRun    = _data!['last_run']  as Map<String, dynamic>?;
    final paused       = drawdownData['is_paused'] as bool? ?? false;

    final totalPnl = positions.fold<double>(
      0,
          (sum, p) =>
      sum + ((p as Map<String, dynamic>)['pnl_abs_eur'] as num? ?? 0).toDouble(),
    );

    final drawdown = (drawdownData['drawdown_pct']       as num?) ?? 0;
    final ddLimit  = (drawdownData['drawdown_limit_pct'] as num?) ?? 25;

    return RefreshIndicator(
      onRefresh: _load,
      color: KestrelColors.gold,
      backgroundColor: KestrelColors.cardBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
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
          _DrawdownStrip(drawdown: drawdown, limit: ddLimit),
          const SizedBox(height: 8),
          _PositionsCard(positions: positions),
          const SizedBox(height: 8),
          if (latestRun != null) _LastRunStrip(latestRun: latestRun),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: const BoxDecoration(
          color: KestrelColors.cardBg,
          border: Border(
            top:    BorderSide(color: KestrelColors.gold, width: 2),
            left:   BorderSide(color: KestrelColors.cardBorder),
            right:  BorderSide(color: KestrelColors.cardBorder),
            bottom: BorderSide(color: KestrelColors.cardBorder),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            const Text(
              'BUDGET',
              style: TextStyle(
                color: KestrelColors.gold,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),

            // Hauptzeile: Gesamtbudget links, investiert + P&L rechts
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${total.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    color: KestrelColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                const Spacer(),
                // Investiert
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${invested.toStringAsFixed(2)} €',
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
                // Unrealisierter P&L
                if (totalPnl != null) ...[
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${pnlPos ? '+' : ''}${totalPnl!.toStringAsFixed(2)} €',
                        style: TextStyle(
                          color: pnlPos ? KestrelColors.green : KestrelColors.red,
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
            const SizedBox(height: 10),

            // Progress Bar
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

// ── Drawdown Strip ────────────────────────────────────────────

class _DrawdownStrip extends StatelessWidget {
  final num drawdown;
  final num limit;
  const _DrawdownStrip({required this.drawdown, required this.limit});

  @override
  Widget build(BuildContext context) {
    final pct      = limit > 0 ? (drawdown / limit).clamp(0.0, 1.0) : 0.0;
    final isWarn   = pct >= 0.7;
    final barColor = isWarn ? KestrelColors.orange : KestrelColors.green;
    final txtColor = isWarn ? KestrelColors.orange : KestrelColors.textDimmed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Drawdown  ${drawdown.toStringAsFixed(1).replaceAll('.', ',')} %'
                    '  ·  Limit ${limit.toStringAsFixed(0)} %',
                style: TextStyle(color: txtColor, fontSize: 10),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)} %',
                style: TextStyle(
                  color: txtColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: pct.toDouble(),
                backgroundColor: KestrelColors.cardBorder,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            CustomPaint(
              size: const Size(40, 40),
              painter: _EmptyPositionIconPainter(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Keine offenen Positionen',
              style: TextStyle(
                color: KestrelColors.textGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gekaufte Aktien erscheinen hier',
              style: TextStyle(color: KestrelColors.textHint, fontSize: 11),
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

  Color _borderColor() {
    final signals = position['signals'] as List? ?? [];
    if (signals.isEmpty) return KestrelColors.green;
    final severities = signals
        .map((s) => (s as Map<String, dynamic>)['severity'] as String? ?? '')
        .toList();
    if (severities.contains('HARD')) return KestrelColors.red;
    if (severities.contains('WARN')) return KestrelColors.orange;
    return KestrelColors.green;
  }

  String _positionValue() {
    final price = (position['last_known_price_eur'] as num?)?.toDouble()
        ?? (position['entry_price_eur'] as num?)?.toDouble();
    final qty   = (position['quantity'] as num?)?.toDouble();
    if (price == null || qty == null) return '–';
    return 'Gesamtwert ${(price * qty).toStringAsFixed(2)} €';
  }

  @override
  Widget build(BuildContext context) {
    final ticker = position['ticker']      as String? ?? '–';
    final qty    = (position['quantity']   as num?)   ?? 0;
    final pnl    = position['pnl_abs_eur'] as num?;
    final pnlPct = position['pnl_pct']     as num?;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: KestrelColors.screenBg,
            border: Border(
              left:   BorderSide(color: _borderColor(), width: 3),
              top:    const BorderSide(color: KestrelColors.cardBorder),
              right:  const BorderSide(color: KestrelColors.cardBorder),
              bottom: const BorderSide(color: KestrelColors.cardBorder),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Ticker + Stück · Gesamtwert
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticker,
                      style: const TextStyle(
                        color: KestrelColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$qty Stück · ${_positionValue()}',
                      style: const TextStyle(
                          color: KestrelColors.textGrey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // P&L rechts
              if (pnl != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)} €',
                      style: TextStyle(
                        color: pnl >= 0 ? KestrelColors.green : KestrelColors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (pnlPct != null)
                      Text(
                        '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)} %',
                        style: TextStyle(
                          color: pnlPct >= 0
                              ? KestrelColors.green
                              : KestrelColors.red,
                          fontSize: 10,
                        ),
                      ),
                  ],
                )
              else
                const Text(
                  'kein Kurs',
                  style: TextStyle(color: KestrelColors.textHint, fontSize: 11),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: KestrelColors.textHint, size: 16),
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
            style:
            const TextStyle(color: KestrelColors.textGrey, fontSize: 10),
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
                style: TextStyle(color: KestrelColors.textHint, fontSize: 10),
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

// ── Empty State Painter ───────────────────────────────────────

class _EmptyPositionIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF334d68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = Rect.fromLTWH(2, 6, size.width - 4, size.height - 10);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)), paint);
    canvas.drawLine(
        Offset(2, rect.top + 10),
        Offset(size.width - 2, rect.top + 10),
        paint);

    final linePaint = Paint()
      ..color = const Color(0xFF334d68)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(8, rect.top + 18),
        Offset(size.width - 8, rect.top + 18),
        linePaint);
    canvas.drawLine(
        Offset(8, rect.top + 24),
        Offset(size.width * 0.6, rect.top + 24),
        linePaint);
  }

  @override
  bool shouldRepaint(_) => false;
}