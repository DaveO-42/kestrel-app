import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/kestrel_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Map<String, dynamic>? _summary;
  List<dynamic>? _trades;
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
        ApiService.getHistorySummary(),
        ApiService.getHistory(),
      ]);
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _trades  = (results[1] as Map<String, dynamic>)['trades'] as List;
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

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        color: KestrelColors.gold,
        backgroundColor: KestrelColors.cardBg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          children: [
            _PnlHero(summary: _summary!),
            const SizedBox(height: 8),
            _TradeList(trades: _trades!),
          ],
        ),
      ),
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
          const Text('History',
              style: TextStyle(
                  color: KestrelColors.goldLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
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

// ── P&L Hero ──────────────────────────────────────────────────

class _PnlHero extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _PnlHero({required this.summary});

  @override
  Widget build(BuildContext context) {
    final totalPnl    = summary['total_pnl_eur']   as num;
    final winRate     = summary['win_rate_pct']     as num;
    final avgReturn   = summary['avg_return_pct']   as num;
    final avgHold     = summary['avg_hold_days']    as num;
    final maxDD       = summary['max_drawdown_pct'] as num;
    final sharpe      = summary['sharpe_ratio']     as num?;
    final tradeCount  = (summary['trade_count']     as num).toInt();
    final isPos       = totalPnl >= 0;

    return GoldTopCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TOTAL P&L', style: kCardLabelStyle),
            const SizedBox(height: 4),
            Text(
              fmtPrice(totalPnl, showSign: true),
              style: TextStyle(
                color: isPos ? KestrelColors.green : KestrelColors.red,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            // Stats-Grid
            Row(
              children: [
                Expanded(child: _StatCell(
                  value: '${winRate.toStringAsFixed(0).replaceAll('.', ',')} %',
                  label: 'Win-Rate',
                )),
                const SizedBox(width: 6),
                Expanded(child: _StatCell(
                  value: fmtPct(avgReturn, showSign: true),
                  label: 'Ø Return',
                  valueColor: avgReturn >= 0 ? KestrelColors.green : KestrelColors.red,
                )),
                const SizedBox(width: 6),
                Expanded(child: _StatCell(
                  value: '${avgHold.toStringAsFixed(0).replaceAll('.', ',')} d',
                  label: 'Ø Haltedauer',
                )),
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
                  _MiniStat(label: 'Trades', value: '$tradeCount'),
                  _MiniStat(label: 'Max DD',
                      value: '-${maxDD.toStringAsFixed(1).replaceAll('.', ',')} %'),
                  _MiniStat(label: 'Sharpe',
                      value: sharpe != null
                          ? sharpe.toStringAsFixed(2).replaceAll('.', ',')
                          : '–'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  const _StatCell({required this.value, required this.label, this.valueColor});

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
              style: TextStyle(
                  color: valueColor ?? KestrelColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: KestrelColors.textGrey, fontSize: 9)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label  ', style: const TextStyle(color: KestrelColors.textDimmed, fontSize: 10)),
        Text(value,     style: const TextStyle(color: KestrelColors.textGrey,    fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Trade List ────────────────────────────────────────────────

class _TradeList extends StatelessWidget {
  final List trades;
  const _TradeList({required this.trades});

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: KestrelColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KestrelColors.cardBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Text('Noch keine abgeschlossenen Trades',
              style: TextStyle(color: KestrelColors.textDimmed, fontSize: 13)),
        ),
      );
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
          Text(
            'ABGESCHLOSSENE TRADES (${trades.length})',
            style: kCardLabelStyle,
          ),
          const SizedBox(height: 8),
          ...trades.asMap().entries.map((entry) {
            final isLast = entry.key == trades.length - 1;
            return Column(
              children: [
                _TradeRow(trade: entry.value as Map<String, dynamic>),
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

class _TradeRow extends StatelessWidget {
  final Map<String, dynamic> trade;
  const _TradeRow({required this.trade});

  // Datum formatieren: "2026-04-03" → "03.04.2026"
  String _fmtDate(String? iso) {
    if (iso == null || iso.length < 10) return '–';
    final parts = iso.substring(0, 10).split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final pnl    = trade['pnl_eur']  as num?;
    final pnlPct = trade['pnl_pct']  as num?;
    final isPos  = (pnl ?? 0) >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trade['ticker'] as String,
                  style: const TextStyle(
                      color: KestrelColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(_fmtDate(trade['exit_date'] as String?),
                  style: const TextStyle(
                      color: KestrelColors.textGrey, fontSize: 10)),
            ],
          ),
          if (pnl != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtPrice(pnl, showSign: true),
                    style: TextStyle(
                        color: isPos ? KestrelColors.green : KestrelColors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(fmtPct(pnlPct),
                    style: TextStyle(
                        color: isPos ? KestrelColors.green : KestrelColors.red,
                        fontSize: 10)),
              ],
            ),
        ],
      ),
    );
  }
}


// GoldTopCard kommt aus kestrel_theme.dart