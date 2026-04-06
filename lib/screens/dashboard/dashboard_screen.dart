import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';
import '../positions/position_detail_screen.dart';

// ── Dashboard Screen ──────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getDashboard();
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: KestrelColors.screenBg,
        body: Center(
          child: CircularProgressIndicator(color: KestrelColors.gold),
        ),
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

    final budget    = _data!['budget']     as Map<String, dynamic>;
    final positions = _data!['positions']  as List;
    final system    = _data!['system']     as Map<String, dynamic>;
    final latestRun = _data!['latest_run'] as Map<String, dynamic>;
    final paused    = system['paused']     as bool;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          if (paused) PauseBanner(
            drawdownPct: system['drawdown_pct'] as num?,
            reason: system['pause_reason'] as String?,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: KestrelColors.gold,
              backgroundColor: KestrelColors.cardBg,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                children: [
                  _BudgetHero(budget: budget),
                  const SizedBox(height: 8),
                  _SystemCard(system: system, latestRun: latestRun),
                  const SizedBox(height: 8),
                  _PositionsCard(positions: positions),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
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
          icon: const Icon(Icons.refresh, color: KestrelColors.textDimmed),
          onPressed: () {
            setState(() => _loading = true);
            _load();
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: KestrelColors.cardBorder),
      ),
    );
  }
}

// GoldTopCard kommt aus kestrel_theme.dart

// ── Budget Hero ───────────────────────────────────────────────

class _BudgetHero extends StatelessWidget {
  final Map<String, dynamic> budget;
  const _BudgetHero({required this.budget});

  @override
  Widget build(BuildContext context) {
    final total    = budget['total_eur']     as num;
    final available= budget['available_eur'] as num;
    final invested = budget['invested_eur']  as num;
    final usedPct  = (invested / total * 100).toStringAsFixed(0);
    final progress = (invested / total).clamp(0.0, 1.0).toDouble();

    return GoldTopCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
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
                    const SizedBox(height: 2),
                    const Text(
                      'investiert',
                      style: TextStyle(color: KestrelColors.textGrey, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: KestrelColors.screenBg,
                  valueColor: const AlwaysStoppedAnimation(KestrelColors.gold),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$usedPct% investiert',
                    style: const TextStyle(color: KestrelColors.textGrey, fontSize: 10)),
                Text('${fmtPrice(available)} verfügbar',
                    style: const TextStyle(color: KestrelColors.textGrey, fontSize: 10)),
              ],
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
    final paused    = system['paused']                  as bool;
    final drawdown  = system['drawdown_pct']             as num;
    final losses    = (system['consecutive_losses']     as num).toInt();
    final lossLimit = (system['consecutive_loss_limit'] as num).toInt();
    final lastPing  = system['last_ping_at']             as String?;
    final runStatus = latestRun['order_status']          as String;
    final runTicker = latestRun['order_ticker']          as String?;
    final runId     = latestRun['run_id']                as String;

    final runTime = runId.length >= 13
        ? '${runId.substring(9, 11)}:${runId.substring(11, 13)}'
        : runId;

    String pingDisplay = '–';
    if (lastPing != null) {
      try {
        final dt = DateTime.parse(lastPing);
        pingDisplay =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        pingDisplay = lastPing;
      }
    }

    return GoldTopCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SYSTEM', style: kCardLabelStyle),
                _StatusBadge(paused: paused),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _InnerCell(value: '${drawdown.toStringAsFixed(1)}%', label: 'Drawdown')),
                const SizedBox(width: 6),
                Expanded(child: _InnerCell(value: '$losses / $lossLimit', label: 'Verluste')),
                const SizedBox(width: 6),
                Expanded(child: _InnerCell(value: pingDisplay, label: 'Letzter Ping')),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: KestrelColors.screenBg,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: KestrelColors.cardBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Letzter Run',
                      style: TextStyle(color: KestrelColors.textGrey, fontSize: 10)),
                  Text(
                    '$runTime · ${runTicker != null ? "$runStatus ($runTicker)" : runStatus}',
                    style: const TextStyle(color: KestrelColors.textDimmed, fontSize: 10),
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
        color: paused ? KestrelColors.redBg : KestrelColors.greenBg,
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
          Text(value,
              style: const TextStyle(
                  color: KestrelColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: KestrelColors.textGrey, fontSize: 9)),
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
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Keine offenen Positionen',
                  style: TextStyle(color: KestrelColors.textGrey, fontSize: 13)),
            )
          else
            ...positions.asMap().entries.map((entry) {
              final isLast = entry.key == positions.length - 1;
              return Column(
                children: [
                  _PositionRow(position: entry.value as Map<String, dynamic>),
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

class _PositionRow extends StatelessWidget {
  final Map<String, dynamic> position;
  const _PositionRow({required this.position});

  Color _trafficLight() {
    final signals = position['signals'] as List? ?? [];
    if (signals.any((s) => (s as Map)['severity'] == 'HARD')) return KestrelColors.red;
    final price = (position['last_known_price_eur'] as num?)?.toDouble();
    final stop  = (position['current_stop_eur']     as num?)?.toDouble();
    if (price != null && stop != null && stop > 0) {
      if ((price - stop) / stop <= 0.05) return KestrelColors.red;
    }
    if (signals.any((s) => (s as Map)['severity'] == 'WARN')) return KestrelColors.orange;
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
          builder: (_) => PositionDetailScreen(ticker: position['ticker'] as String),
        ),
      ),
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
                    Text(position['ticker'] as String,
                        style: const TextStyle(
                            color: KestrelColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Entry €${position['entry_price_eur']} · Stop €${position['current_stop_eur']}',
                      style: const TextStyle(color: KestrelColors.textGrey, fontSize: 10),
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
                          color: isPos ? KestrelColors.green : KestrelColors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fmtPct(pnlPct),
                      style: TextStyle(
                          color: isPos ? KestrelColors.green : KestrelColors.red,
                          fontSize: 10),
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