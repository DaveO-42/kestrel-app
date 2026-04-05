import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class PositionDetailScreen extends StatefulWidget {
  final String ticker;
  const PositionDetailScreen({super.key, required this.ticker});

  @override
  State<PositionDetailScreen> createState() => _PositionDetailScreenState();
}

class _PositionDetailScreenState extends State<PositionDetailScreen> {
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
      final data = await ApiService.getPosition(widget.ticker);
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

    final p = _data!;
    final pnl = p['pnl_eur'] as num?;
    final pnlPct = p['pnl_pct'] as num?;
    final isPositive = (pnl ?? 0) >= 0;
    final signals = p['signals'] as List;

    return Scaffold(
      appBar: AppBar(
        title: Text(p['ticker']),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── P&L ───────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Performance',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _DetailItem(
                        label: 'P&L',
                        value: '${isPositive ? '+' : ''}€${pnl?.toStringAsFixed(2) ?? '-'}',
                        valueColor: isPositive ? Colors.green : Colors.red,
                      ),
                      _DetailItem(
                        label: 'Return',
                        value: '${isPositive ? '+' : ''}${pnlPct?.toStringAsFixed(2) ?? '-'}%',
                        valueColor: isPositive ? Colors.green : Colors.red,
                      ),
                      _DetailItem(
                        label: 'Kurs (zuletzt)',
                        value: '€${p['last_known_price_eur'] ?? '-'}',
                      ),
                    ],
                  ),
                  if (p['price_updated_at'] != null) ...[
                    const SizedBox(height: 8),
                    Text('Stand: ${p['price_updated_at']}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Trade-Parameter ───────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trade-Parameter',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _DetailItem(
                          label: 'Entry', value: '€${p['entry_price_eur']}'),
                      _DetailItem(
                          label: 'Stück', value: '${p['quantity']}'),
                      _DetailItem(
                          label: 'ATR', value: '€${p['atr_at_entry_eur']}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _DetailItem(
                          label: 'Stop (initial)',
                          value: '€${p['initial_stop_eur']}'),
                      _DetailItem(
                          label: 'Stop (aktuell)',
                          value: '€${p['current_stop_eur']}'),
                      _DetailItem(
                          label: 'Höchstkurs',
                          value: '€${p['highest_close_eur']}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Stop-Modus: ',
                          style: Theme.of(context).textTheme.bodySmall),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p['stop_mode'] == 'warn'
                              ? Colors.orange.withOpacity(0.2)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p['stop_mode'] == 'warn' ? 'WARN (ATR×1.0)' : 'Normal (ATR×2.0)',
                          style: TextStyle(
                            fontSize: 12,
                            color: p['stop_mode'] == 'warn'
                                ? Colors.orange
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Signale ───────────────────────────────────────────
          if (signals.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Signale',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ...signals.map((s) => _SignalRow(signal: s)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ── Notizen ───────────────────────────────────────────
          if (p['notes'] != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Katalysator',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(p['notes'],
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ── Entry-Datum ───────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Einstiegsdatum',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(p['entry_date'],
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hilfs-Widgets ─────────────────────────────────────────────

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailItem({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: valueColor),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SignalRow extends StatelessWidget {
  final Map<String, dynamic> signal;
  const _SignalRow({required this.signal});

  Color _color(String severity) {
    switch (severity) {
      case 'HARD':
        return Colors.red;
      case 'WARN':
        return Colors.orange;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severity = signal['severity'] as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _color(severity).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              severity,
              style: TextStyle(
                  color: _color(severity),
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(signal['message'])),
        ],
      ),
    );
  }
}