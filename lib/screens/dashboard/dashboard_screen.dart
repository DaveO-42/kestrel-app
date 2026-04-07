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

  @override
  Widget build(BuildContext context) {
    // Kombination: lokaler Ladefehler ODER globaler Verbindungsfehler aus Settings
    final globalError = KestrelNav.of(context)?.connectionError ?? false;
    final showError   = _connError || globalError;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: KestrelColors.gold))
          : showError
          ? _buildErrorBody()
          : _buildBody(),
    );
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
          icon: const Icon(Icons.refresh,
              color: KestrelColors.textDimmed, size: 20),
          onPressed: _load,
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined,
              color: KestrelColors.textDimmed, size: 20),
          onPressed: () =>
              KestrelNav.of(context)?.goToSettings(),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: KestrelColors.cardBorder),
      ),
    );
  }

  // ── Fehler-Body ───────────────────────────────────────────

  Widget _buildErrorBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        // Error Card
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E0808),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KestrelColors.redBorder),
          ),
          child: Column(
            children: [
              // Gold-top-Linie via foregroundDecoration
              Container(
                height: 2,
                decoration: const BoxDecoration(
                  color: KestrelColors.red,
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'KEINE VERBINDUNG',
                      style: TextStyle(
                        color: KestrelColors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pi nicht erreichbar. Tailscale aktiv?',
                      style: TextStyle(
                        color: KestrelColors.textGrey,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _load,
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border:
                          Border.all(color: KestrelColors.redBorder),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Erneut versuchen',
                          style: TextStyle(
                            color: KestrelColors.red,
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
        ),
        const SizedBox(height: 8),
        // Gedimmter Budget-Hero
        Opacity(
          opacity: 0.25,
          child: _BudgetHero(budget: {
            'total_eur': 0,
            'available_eur': 0,
            'invested_eur': 0,
          }),
        ),
        const SizedBox(height: 8),
        // Gedimmte System-Card
        Opacity(
          opacity: 0.25,
          child: _SystemCard(
            system: {
              'paused': false,
              'drawdown_pct': 0,
              'drawdown_threshold_pct': 25,
              'consecutive_losses': 0,
              'consecutive_loss_limit': 6,
              'last_ping_at': null,
            },
            latestRun: {
              'run_id': '',
              'order_status': '–',
              'order_ticker': null,
            },
          ),
        ),
      ],
    );
  }

  // ── Normal-Body ───────────────────────────────────────────

  Widget _buildBody() {
    final budget    = _data!['budget']     as Map<String, dynamic>;
    final positions = _data!['positions']  as List? ?? [];
    final system    = _data!['system']     as Map<String, dynamic>;
    final latestRun = _data!['latest_run'] as Map<String, dynamic>;
    final paused    = system['paused']     as bool? ?? false;

    return RefreshIndicator(
      onRefresh: _load,
      color: KestrelColors.gold,
      backgroundColor: KestrelColors.cardBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          if (paused)
            PauseBanner(
              drawdownPct: system['drawdown_pct'] as num?,
              reason: system['pause_reason'] as String?,
            ),
          _BudgetHero(budget: budget),
          const SizedBox(height: 8),
          _SystemCard(system: system, latestRun: latestRun),
          const SizedBox(height: 8),
          _PositionsCard(positions: positions),
        ],
      ),
    );
  }
}

// ── Budget Hero ───────────────────────────────────────────────

class _BudgetHero extends StatelessWidget {
  final Map<String, dynamic> budget;
  const _BudgetHero({required this.budget});

  @override
  Widget build(BuildContext context) {
    final total     = (budget['total_eur']     as num?) ?? 0;
    final available = (budget['available_eur'] as num?) ?? 0;
    final invested  = (budget['invested_eur']  as num?) ?? 0;
    final pct       = total > 0 ? (invested / total).clamp(0.0, 1.0) : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: KestrelColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KestrelColors.cardBorder),
        ),
        child: Column(
          children: [
            Container(
              height: 2,
              color: KestrelColors.gold,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 11),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BUDGET', style: kCardLabelStyle),
                          const SizedBox(height: 4),
                          Text(
                            fmtPrice(total),
                            style: const TextStyle(
                              color: KestrelColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
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
                              color: KestrelColors.textGrey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: KestrelColors.screenBg,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: KestrelColors.cardBorder),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: pct.toDouble(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: KestrelColors.gold,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}% investiert',
                        style: const TextStyle(
                          color: KestrelColors.textGrey,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '${fmtPrice(available)} verfügbar',
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
          ],
        ),
      ),
    );
  }
}

// ── System Card ───────────────────────────────────────────────

class _SystemCard extends StatelessWidget {
  final Map<String, dynamic> system;
  final Map<String, dynamic> latestRun;
  const _SystemCard({required this.system, required this.latestRun});

  @override
  Widget build(BuildContext context) {
    final paused    = system['paused']                 as bool?  ?? false;
    final drawdown  = (system['drawdown_pct']          as num?)  ?? 0;
    final threshold = (system['drawdown_threshold_pct'] as num?) ?? 25;
    final losses    = ((system['consecutive_losses']   as num?)  ?? 0).toInt();
    final lossLimit = ((system['consecutive_loss_limit'] as num?) ?? 6).toInt();
    final lastPing  = system['last_ping_at']           as String?;
    final runStatus = latestRun['order_status']        as String? ?? '–';
    final runTicker = latestRun['order_ticker']        as String?;
    final runId     = latestRun['run_id']              as String? ?? '';

    final pingTime = lastPing != null && lastPing.length >= 19
        ? lastPing.substring(11, 19)
        : '–';
    final runTime = runId.length >= 13
        ? '${runId.substring(9, 11)}:${runId.substring(11, 13)}'
        : '–';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: KestrelColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KestrelColors.cardBorder),
        ),
        child: Column(
          children: [
            Container(height: 2, color: KestrelColors.gold),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 11),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('SYSTEM', style: kCardLabelStyle),
                      _StatusBadge(paused: paused),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _InnerCell(
                          value: '${drawdown.toStringAsFixed(1)}%',
                          label: 'Drawdown',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _InnerCell(
                          value: '$losses / $lossLimit',
                          label: 'Verluste',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _InnerCell(
                          value: pingTime,
                          label: 'Letzter Ping',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: KestrelColors.screenBg,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: KestrelColors.cardBorder),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Letzter Run',
                          style: TextStyle(
                            color: KestrelColors.textGrey,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          runId.isEmpty
                              ? 'noch kein Run'
                              : '$runTime · $runStatus${runTicker != null ? ' ($runTicker)' : ''}',
                          style: const TextStyle(
                            color: KestrelColors.textDimmed,
                            fontSize: 10,
                          ),
                        ),
                      ],
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

class _StatusBadge extends StatelessWidget {
  final bool paused;
  const _StatusBadge({required this.paused});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: paused ? const Color(0xFF200808) : const Color(0xFF0A2016),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: paused ? KestrelColors.redBorder : KestrelColors.greenBorder,
        ),
      ),
      child: Text(
        paused ? 'PAUSIERT' : 'AKTIV',
        style: TextStyle(
          color: paused ? KestrelColors.red : KestrelColors.green,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InnerCell extends StatelessWidget {
  final String value;
  final String label;
  const _InnerCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KestrelColors.screenBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: KestrelColors.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: KestrelColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: KestrelColors.textGrey,
              fontSize: 9,
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
            style: kCardLabelStyle,
          ),
          const SizedBox(height: 10),
          if (positions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CustomPaint(
                          painter: _EmptyPositionIconPainter()),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Keine offenen Positionen',
                      style: TextStyle(
                        color: Color(0xFF6A8AAA),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gekaufte Aktien erscheinen hier',
                      style: TextStyle(
                        color: Color(0xFF334D68),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...positions.asMap().entries.map((entry) {
              final isLast = entry.key == positions.length - 1;
              return Column(
                children: [
                  _PositionRow(
                      position: entry.value as Map<String, dynamic>),
                  if (!isLast)
                    const Divider(
                        height: 1, color: KestrelColors.cardBorder),
                ],
              );
            }),
        ],
      ),
    );
  }
}

// ── Empty State Painter ───────────────────────────────────────

class _EmptyPositionIconPainter extends CustomPainter {
  const _EmptyPositionIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF334D68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.125, h * 0.25, w * 0.75, h * 0.5625),
        const Radius.circular(3),
      ),
      p,
    );
    canvas.drawLine(
      Offset(w * 0.125, h * 0.40625),
      Offset(w * 0.875, h * 0.40625),
      p,
    );
    p.strokeWidth = 1.2;
    canvas.drawLine(
      Offset(w * 0.3125, h * 0.59375),
      Offset(w * 0.4375, h * 0.59375),
      p,
    );
    canvas.drawLine(
      Offset(w * 0.3125, h * 0.6875),
      Offset(w * 0.5, h * 0.6875),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Position Row ──────────────────────────────────────────────

class _PositionRow extends StatelessWidget {
  final Map<String, dynamic> position;
  const _PositionRow({required this.position});

  Color _trafficLight() {
    final signals = position['signals'] as List? ?? [];
    if (signals.any((s) => (s as Map)['severity'] == 'HARD'))
      return KestrelColors.red;
    final price = (position['last_known_price_eur'] as num?)?.toDouble();
    final stop  = (position['current_stop_eur']     as num?)?.toDouble();
    if (price != null && stop != null && stop > 0) {
      if ((price - stop) / stop <= 0.05) return KestrelColors.red;
    }
    if (signals.any((s) => (s as Map)['severity'] == 'WARN'))
      return KestrelColors.orange;
    return KestrelColors.green;
  }

  @override
  Widget build(BuildContext context) {
    final pnl    = position['pnl_eur']  as num?;
    final pnlPct = position['pnl_pct']  as num?;
    final isPos  = (pnl ?? 0) >= 0;
    final color  = _trafficLight();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PositionDetailScreen(
            ticker: position['ticker'] as String,
          ),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 3,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      position['ticker'] as String,
                      style: const TextStyle(
                        color: KestrelColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Entry ${fmtPrice(position['entry_price_eur'] as num?)} · Stop ${fmtPrice(position['current_stop_eur'] as num?)}',
                      style: const TextStyle(
                        color: KestrelColors.textGrey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (pnl != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fmtPrice(pnl, showSign: true),
                      style: TextStyle(
                        color:
                        isPos ? KestrelColors.green : KestrelColors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fmtPct(pnlPct),
                      style: TextStyle(
                        color:
                        isPos ? KestrelColors.green : KestrelColors.red,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}