import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Map<String, dynamic>? _summary;
  List<dynamic>? _trades;
  Map<String, dynamic>? _system;
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
        ApiService.getHistorySummary(),
        ApiService.getHistory(),
        ApiService.getSystemStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _trades  = (results[1] as Map<String, dynamic>)['trades'] as List;
        _system  = results[2] as Map<String, dynamic>;
        _loading = false;
      });
      if (!ApiService.useMock) KestrelNav.of(context)?.setConnectionError(false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!ApiService.useMock) KestrelNav.of(context)?.setConnectionError(true);
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
    final paused    = _system?['paused'] as bool? ?? false;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (paused)
            PauseBanner(
              drawdownPct: _system?['drawdown_pct'] as num?,
              reason: _system?['pause_reason'] as String?,
            ),
          if (connError) const ErrorBanner(),
          Expanded(
            child: connError
                ? _buildErrorBody()
                : RefreshIndicator(
              onRefresh: _load,
              color: KestrelColors.gold,
              backgroundColor: KestrelColors.cardBg,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                children: [
                  if (_summary != null)
                    _PnlHero(summary: _summary!),
                  const SizedBox(height: 8),
                  if (_trades != null)
                    _TradeList(trades: _trades!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        Opacity(
          opacity: 0.25,
          child: _GoldTopCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL P&L', style: kCardLabelStyle),
                  const SizedBox(height: 4),
                  const Text('–',
                      style: TextStyle(
                        color: KestrelColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: 0.25,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: KestrelColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KestrelColors.cardBorder),
            ),
          ),
        ),
      ],
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
            'History',
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

// ── P&L Hero ──────────────────────────────────────────────────

class _PnlHero extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _PnlHero({required this.summary});

  @override
  Widget build(BuildContext context) {
    final totalPnl   = (summary['total_pnl_eur']   as num?) ?? 0;
    final winRate    = (summary['win_rate_pct']     as num?) ?? 0;
    final avgReturn  = (summary['avg_return_pct']   as num?) ?? 0;
    final avgHold    = (summary['avg_hold_days']    as num?) ?? 0;
    final maxDD      = (summary['max_drawdown_pct'] as num?) ?? 0;
    final sharpe     = summary['sharpe_ratio']      as num?;
    final tradeCount = ((summary['trade_count']     as num?) ?? 0).toInt();
    final isPos      = totalPnl >= 0;

    return _GoldTopCard(
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
            Row(
              children: [
                Expanded(
                    child: _StatCell(
                      value:
                      '${winRate.toStringAsFixed(0).replaceAll('.', ',')} %',
                      label: 'Win-Rate',
                    )),
                const SizedBox(width: 6),
                Expanded(
                    child: _StatCell(
                      value: fmtPct(avgReturn, showSign: true),
                      label: 'Ø Return',
                      valueColor: avgReturn >= 0
                          ? KestrelColors.green
                          : KestrelColors.red,
                    )),
                const SizedBox(width: 6),
                Expanded(
                    child: _StatCell(
                      value: '${avgHold.toStringAsFixed(0)}d',
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
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Max DD  ${maxDD.toStringAsFixed(1)} %',
                    style: const TextStyle(
                        color: KestrelColors.textGrey, fontSize: 10),
                  ),
                  if (sharpe != null)
                    Text(
                      'Sharpe  ${sharpe.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: KestrelColors.textGrey, fontSize: 10),
                    ),
                  Text(
                    '$tradeCount Trades',
                    style: const TextStyle(
                        color: KestrelColors.textDimmed, fontSize: 10),
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
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? KestrelColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: KestrelColors.textGrey, fontSize: 9)),
        ],
      ),
    );
  }
}

// ── Trade List ────────────────────────────────────────────────

class _TradeList extends StatelessWidget {
  final List trades;
  const _TradeList({required this.trades});

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
            'ABGESCHLOSSENE TRADES (${trades.length})',
            style: kCardLabelStyle,
          ),
          const SizedBox(height: 8),
          if (trades.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Noch keine abgeschlossenen Trades',
                style: TextStyle(
                    color: KestrelColors.textGrey, fontSize: 12),
              ),
            )
          else
            ...trades.asMap().entries.map((entry) {
              final isLast = entry.key == trades.length - 1;
              return Column(
                children: [
                  _TradeRow(trade: entry.value as Map<String, dynamic>),
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

class _TradeRow extends StatelessWidget {
  final Map<String, dynamic> trade;
  const _TradeRow({required this.trade});

  String _fmtDate(String? iso) {
    if (iso == null || iso.length < 10) return '–';
    final parts = iso.substring(0, 10).split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final pnl    = trade['pnl_eur'] as num?;
    final pnlPct = trade['pnl_pct'] as num?;
    final isPos  = (pnl ?? 0) >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trade['ticker'] as String,
                style: const TextStyle(
                  color: KestrelColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _fmtDate(trade['exit_date'] as String?),
                style: const TextStyle(
                    color: KestrelColors.textGrey, fontSize: 10),
              ),
            ],
          ),
          if (pnl != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
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
    );
  }
}

// ── Gold Top Card ─────────────────────────────────────────────

class _GoldTopCard extends StatelessWidget {
  final Widget child;
  const _GoldTopCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: KestrelColors.cardBg,
          border: Border.all(color: KestrelColors.cardBorder),
        ),
        child: Column(
          children: [
            Container(height: 2, color: KestrelColors.gold),
            child,
          ],
        ),
      ),
    );
  }
}