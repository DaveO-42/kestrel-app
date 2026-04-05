import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../positions/position_detail_screen.dart';

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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Fehler: $_error')),
      );
    }

    final budget = _data!['budget'];
    final positions = _data!['positions'] as List;
    final system = _data!['system'];
    final latestRun = _data!['latest_run'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kestrel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _BudgetCard(budget: budget),
            const SizedBox(height: 12),
            _SystemCard(system: system, latestRun: latestRun),
            const SizedBox(height: 12),
            _PositionsCard(positions: positions),
          ],
        ),
      ),
    );
  }
}

// ── Budget Card ───────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final Map<String, dynamic> budget;
  const _BudgetCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final total = budget['total_eur'] as num;
    final available = budget['available_eur'] as num;
    final invested = budget['invested_eur'] as num;
    final usedPct = (invested / total * 100).toStringAsFixed(0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Budget', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _BudgetItem(label: 'Gesamt', value: '€${total.toStringAsFixed(0)}'),
                _BudgetItem(label: 'Verfügbar', value: '€${available.toStringAsFixed(2)}'),
                _BudgetItem(label: 'Investiert', value: '€${invested.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: invested / total,
              backgroundColor: Colors.white12,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Text('$usedPct% investiert',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _BudgetItem extends StatelessWidget {
  final String label;
  final String value;
  const _BudgetItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
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
    final paused = system['paused'] as bool;
    final drawdown = system['drawdown_pct'] as num;
    final threshold = system['drawdown_threshold_pct'] as num;
    final losses = system['consecutive_losses'] as int;
    final runStatus = latestRun['order_status'] as String;
    final runTicker = latestRun['order_ticker'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('System', style: Theme.of(context).textTheme.titleMedium),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: paused ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    paused ? 'PAUSIERT' : 'AKTIV',
                    style: TextStyle(
                      color: paused ? Colors.red : Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Drawdown: ${drawdown.toStringAsFixed(1)}% / ${threshold.toStringAsFixed(0)}%'),
                Text('Verluste: $losses'),
              ],
            ),
            const SizedBox(height: 8),
            Text('Letzter Run: $runStatus${runTicker != null ? ' ($runTicker)' : ''}',
                style: Theme.of(context).textTheme.bodySmall),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Offene Positionen (${positions.length})',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (positions.isEmpty)
              const Text('Keine offenen Positionen')
            else
              ...positions.map((p) => _PositionRow(position: p)),
          ],
        ),
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  final Map<String, dynamic> position;
  const _PositionRow({required this.position});

  @override
  Widget build(BuildContext context) {
    final pnl = position['pnl_eur'] as num?;
    final pnlPct = position['pnl_pct'] as num?;
    final isPositive = (pnl ?? 0) >= 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PositionDetailScreen(ticker: position['ticker']),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(position['ticker'],
                    style: Theme.of(context).textTheme.titleSmall),
                Text('Entry: €${position['entry_price_eur']} · Stop: €${position['current_stop_eur']}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (pnl != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isPositive ? '+' : ''}€${pnl.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${isPositive ? '+' : ''}${pnlPct?.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}