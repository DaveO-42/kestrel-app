import 'package:flutter/material.dart';
import '../../theme/kestrel_theme.dart';

class TradeDetailScreen extends StatelessWidget {
  final Map<String, dynamic> trade;
  const TradeDetailScreen({super.key, required this.trade});

  String _fmtDate(String? iso) {
    if (iso == null || iso.length < 10) return '–';
    final parts = iso.substring(0, 10).split('-');
    if (parts.length != 3) return '–';
    final yy = parts[0].length >= 2 ? parts[0].substring(2) : parts[0];
    return '${parts[2]}.${parts[1]}.$yy';
  }

  int _holdDays(String? entryIso, String? exitIso) {
    if (entryIso == null || exitIso == null) return 0;
    final entry = DateTime.tryParse(entryIso);
    final exit  = DateTime.tryParse(exitIso);
    if (entry == null || exit == null) return 0;
    return exit.difference(entry).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final ticker     = trade['ticker']           as String? ?? '–';
    final pnl        = trade['pnl_abs_eur']      as num?;
    final pnlPct     = trade['pnl_pct']          as num?;
    final entryPrice = trade['entry_price_eur']  as num?;
    final exitPrice  = trade['exit_price_eur']   as num?;
    final quantity   = trade['quantity']         as num?;
    final initStop   = trade['initial_stop_eur'] as num?;
    final atr        = trade['atr_at_entry_eur'] as num?;
    final entryDate  = trade['entry_date']       as String?;
    final exitDate   = trade['exit_date']        as String?;
    final exitReason = trade['exit_reason']      as String?;
    final notes      = trade['notes']            as String?;

    final isWin    = (pnl ?? 0) >= 0;
    final pnlColor = isWin ? KestrelColors.green : KestrelColors.red;

    final positionSize = (entryPrice != null && quantity != null)
        ? entryPrice.toDouble() * quantity.toDouble()
        : null;

    double? rMultiple;
    double? riskEur;
    if (entryPrice != null && initStop != null && quantity != null && pnl != null) {
      final risk = (entryPrice.toDouble() - initStop.toDouble()) * quantity.toDouble();
      if (risk != 0) {
        riskEur   = risk;
        rMultiple = pnl.toDouble() / risk;
      }
    }

    final holdDays = _holdDays(entryDate, exitDate);

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: AppBar(
        backgroundColor: KestrelColors.appBarBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: KestrelColors.textDimmed, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            KestrelLogo(size: 22),
            const SizedBox(width: 8),
            const Text(
              'Trade Detail',
              style: TextStyle(
                color: KestrelColors.goldLight,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: KestrelColors.cardBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [

          // ── 1. Hero Card ──────────────────────────────────────
          GoldTopCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(ticker,
                          style: const TextStyle(
                              color: KestrelColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                      _WinLossBadge(isWin: isWin),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fmtPrice(pnl, showSign: true),
                    style: TextStyle(
                        color: pnlColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fmtPct(pnlPct),
                    style: TextStyle(color: pnlColor, fontSize: 13),
                  ),
                  if (exitReason != null && exitReason.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ExitReasonPill(reason: exitReason),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── 2. R-Multiple Card ────────────────────────────────
          _Card(
            label: 'R-MULTIPLE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rMultiple != null
                      ? '${rMultiple >= 0 ? '+' : ''}'
                        '${rMultiple.toStringAsFixed(2).replaceAll('.', ',')} R'
                      : '– R',
                  style: TextStyle(
                    color: (rMultiple ?? 0) >= 0
                        ? KestrelColors.green
                        : KestrelColors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  riskEur != null && pnl != null
                      ? 'Risiko: ${fmtPrice(riskEur.abs())} → '
                        '${isWin ? 'Gewinn' : 'Verlust'}: ${fmtPrice(pnl.abs())}'
                      : '–',
                  style: const TextStyle(
                      color: KestrelColors.textGrey, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── 3. Trade-Parameter Card ───────────────────────────
          _Card(
            label: 'TRADE-PARAMETER',
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: _StatCell(
                      value: fmtPrice(entryPrice), label: 'Entry')),
                  const SizedBox(width: 6),
                  Expanded(child: _StatCell(
                      value: '${quantity?.toInt() ?? '–'}', label: 'Stück')),
                  const SizedBox(width: 6),
                  Expanded(child: _StatCell(
                      value: fmtPrice(positionSize), label: 'Position')),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: _StatCell(
                      value: fmtPrice(exitPrice), label: 'Exit')),
                  const SizedBox(width: 6),
                  Expanded(child: _StatCell(
                      value: fmtPrice(initStop), label: 'Stop init.')),
                  const SizedBox(width: 6),
                  Expanded(child: _StatCell(
                      value: fmtPrice(atr), label: 'ATR')),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── 4. Zeitraum Card ──────────────────────────────────
          _Card(
            label: 'ZEITRAUM',
            child: Row(children: [
              Expanded(child: _StatCell(
                  value: _fmtDate(entryDate), label: 'Einstieg')),
              const SizedBox(width: 6),
              Expanded(child: _StatCell(
                  value: _fmtDate(exitDate), label: 'Ausstieg')),
              const SizedBox(width: 6),
              Expanded(child: _StatCell(
                  value: '${holdDays}d', label: 'Haltedauer')),
            ]),
          ),

          // ── 5. Katalysator Card (optional) ────────────────────
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Card(
              label: 'KATALYSATOR',
              child: Text(
                notes,
                style: const TextStyle(
                    color: KestrelColors.textGrey,
                    fontSize: 11,
                    height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String label;
  final Widget child;
  const _Card({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: kCardDecoration(),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: kCardLabelStyle),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── Stat Cell ─────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: kInnerCellDecoration(),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Column(children: [
        Text(value,
            style: const TextStyle(
                color: KestrelColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: KestrelColors.textGrey, fontSize: 9)),
      ]),
    );
  }
}

// ── WIN/LOSS Badge ────────────────────────────────────────────

class _WinLossBadge extends StatelessWidget {
  final bool isWin;
  const _WinLossBadge({required this.isWin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        isWin ? KestrelColors.greenBg     : KestrelColors.redBg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
            color: isWin ? KestrelColors.greenBorder : KestrelColors.redBorder),
      ),
      child: Text(
        isWin ? 'WIN' : 'LOSS',
        style: TextStyle(
          color:       isWin ? KestrelColors.green : KestrelColors.red,
          fontSize:    10,
          fontWeight:  FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Exit Reason Pill ──────────────────────────────────────────

class _ExitReasonPill extends StatelessWidget {
  final String reason;
  const _ExitReasonPill({required this.reason});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color text;

    switch (reason) {
      case 'WarnStop':
        bg     = KestrelColors.orangeBg;
        border = KestrelColors.orangeBorder;
        text   = KestrelColors.orange;
      default:
        bg     = KestrelColors.grayBg;
        border = KestrelColors.grayBorder;
        text   = KestrelColors.textGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Text(
        reason,
        style: TextStyle(
          color:      text,
          fontSize:   10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
