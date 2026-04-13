import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/kestrel_theme.dart';

/// Bottom Sheet zum Bestätigen eines Verkaufs nach manueller Ausführung.
///
/// Vorbefüllt mit [lastKnownPriceEur] (letzter bekannter Kurs aus Pipeline).
/// Zeigt Live P&L-Vorschau beim Tippen.
///
/// Aufruf:
/// ```dart
/// SoldSheet.show(context,
///   ticker: 'NVDA',
///   entryPriceEur: 112.45,
///   quantity: 3,
///   lastKnownPriceEur: 121.30,
///   onSuccess: () => Navigator.of(context).pop(),
/// );
/// ```
class SoldSheet extends StatefulWidget {
  final String ticker;
  final double entryPriceEur;
  final int quantity;
  final double lastKnownPriceEur;
  final VoidCallback onSuccess;

  const SoldSheet({
    super.key,
    required this.ticker,
    required this.entryPriceEur,
    required this.quantity,
    required this.lastKnownPriceEur,
    required this.onSuccess,
  });

  static Future<void> show(
      BuildContext context, {
        required String ticker,
        required double entryPriceEur,
        required int quantity,
        required double lastKnownPriceEur,
        required VoidCallback onSuccess,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SoldSheet(
        ticker: ticker,
        entryPriceEur: entryPriceEur,
        quantity: quantity,
        lastKnownPriceEur: lastKnownPriceEur,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<SoldSheet> createState() => _SoldSheetState();
}

class _SoldSheetState extends State<SoldSheet> {
  late final TextEditingController _fillCtrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fillCtrl = TextEditingController(
        text: widget.lastKnownPriceEur.toStringAsFixed(2));
    _fillCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fillCtrl.dispose();
    super.dispose();
  }

  double get _fill =>
      double.tryParse(_fillCtrl.text.replaceAll(',', '.')) ?? 0;

  double get _pnlEur =>
      _fill > 0 ? (_fill - widget.entryPriceEur) * widget.quantity : 0;

  double get _pnlPct => widget.entryPriceEur > 0
      ? (_fill - widget.entryPriceEur) / widget.entryPriceEur * 100
      : 0;

  bool get _formValid => _fill > 0;

  Future<void> _submit() async {
    if (!_formValid) return;
    setState(() { _loading = true; _error = null; });

    // Bestätigungs-Dialog vor dem Absenden
    final confirmed = await _showConfirmDialog();
    if (!confirmed) {
      setState(() => _loading = false);
      return;
    }

    try {
      await ApiService.postSold(
        ticker: widget.ticker,
        fillPriceEur: _fill,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } on ActionException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KestrelColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: KestrelColors.cardBorder),
        ),
        title: Text(
          '${widget.ticker} verkaufen?',
          style: const TextStyle(
            color: KestrelColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '${widget.quantity} Stück @ €${_fill.toStringAsFixed(2)}\n'
              'P&L: ${_pnlEur >= 0 ? "+" : ""}€${_pnlEur.toStringAsFixed(2)} '
              '(${_pnlPct >= 0 ? "+" : ""}${_pnlPct.toStringAsFixed(1)}%)',
          style: const TextStyle(
            color: KestrelColors.textGrey,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen',
                style: TextStyle(color: KestrelColors.textDimmed)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: KestrelColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Verkaufen',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final hasPnl = _fill > 0;
    final pnlPositive = _pnlEur >= 0;

    return Container(
      decoration: const BoxDecoration(
        color: KestrelColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: KestrelColors.red, width: 2),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────
          Row(children: [
            Text(
              'VERKAUF BESTÄTIGEN',
              style: TextStyle(
                color: KestrelColors.red,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            Text(
              widget.ticker,
              style: const TextStyle(
                color: KestrelColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // ── Meta-Info ──────────────────────────────────────────
          Text(
            '${widget.quantity} Stück · Entry €${widget.entryPriceEur.toStringAsFixed(2)}',
            style: const TextStyle(
              color: KestrelColors.textDimmed,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),

          // ── Fill-Kurs Eingabe ──────────────────────────────────
          Text(
            'FILL-KURS (€)',
            style: TextStyle(
              color: KestrelColors.gold,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _fillCtrl,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
            ],
            autofocus: true,
            style: const TextStyle(
              color: KestrelColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: KestrelColors.screenBg,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: KestrelColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: KestrelColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: KestrelColors.gold),
              ),
              suffixText: 'EUR',
              suffixStyle: const TextStyle(
                color: KestrelColors.textDimmed,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── P&L Vorschau ───────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: KestrelColors.screenBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasPnl
                    ? (pnlPositive
                    ? KestrelColors.green.withOpacity(0.4)
                    : KestrelColors.red.withOpacity(0.4))
                    : KestrelColors.cardBorder,
              ),
            ),
            child: Row(children: [
              Text(
                'P&L Vorschau',
                style: TextStyle(
                    color: KestrelColors.textDimmed, fontSize: 12),
              ),
              const Spacer(),
              if (hasPnl) ...[
                Text(
                  '${pnlPositive ? "+" : ""}€${_pnlEur.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: pnlPositive
                        ? KestrelColors.green
                        : KestrelColors.red,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${pnlPositive ? "+" : ""}${_pnlPct.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    color: (pnlPositive
                        ? KestrelColors.green
                        : KestrelColors.red)
                        .withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ] else
                Text('–',
                    style: TextStyle(color: KestrelColors.textDimmed)),
            ]),
          ),

          // ── Fehler ────────────────────────────────────────────
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: KestrelColors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    color: KestrelColors.red, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          color: KestrelColors.red, fontSize: 12)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 20),

          // ── Buttons ───────────────────────────────────────────
          Row(children: [
            Expanded(
              child: TextButton(
                onPressed:
                _loading ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: KestrelColors.textDimmed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Abbrechen'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (_formValid && !_loading) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KestrelColors.red,
                  disabledBackgroundColor:
                  KestrelColors.red.withOpacity(0.3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  'Verkauf erfassen',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}