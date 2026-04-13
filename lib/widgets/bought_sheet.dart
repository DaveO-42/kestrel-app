import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/kestrel_theme.dart';

/// Bottom Sheet zum Bestätigen eines Kaufs nach manueller Ausführung.
///
/// Vorbefüllt aus [candidate] (Shortlist-Kandidat), alle Felder editierbar.
/// Zeigt Live-Berechnung: Volumen = Stückzahl × Fill-Kurs.
/// Confirm-Button erst aktiv wenn alle Felder valide und Budget ausreicht.
///
/// Aufruf:
/// ```dart
/// BoughtSheet.show(context,
///   candidate: shortlistData['top_candidate'],
///   availableBudgetEur: 402.50,
///   onSuccess: () => setState(() => _load()),
/// );
/// ```
class BoughtSheet extends StatefulWidget {
  final Map<String, dynamic> candidate;
  final double availableBudgetEur;
  final VoidCallback onSuccess;

  const BoughtSheet({
    super.key,
    required this.candidate,
    required this.availableBudgetEur,
    required this.onSuccess,
  });

  static Future<void> show(
      BuildContext context, {
        required Map<String, dynamic> candidate,
        required double availableBudgetEur,
        required VoidCallback onSuccess,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BoughtSheet(
        candidate: candidate,
        availableBudgetEur: availableBudgetEur,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<BoughtSheet> createState() => _BoughtSheetState();
}

class _BoughtSheetState extends State<BoughtSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _qtyCtrl;
  late final TextEditingController _fillCtrl;
  late final TextEditingController _stopCtrl;
  late final TextEditingController _atrCtrl;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tp = widget.candidate['trade_params'] as Map<String, dynamic>? ?? {};
    _qtyCtrl  = TextEditingController(text: '${tp['quantity'] ?? 1}');
    _fillCtrl = TextEditingController(
        text: _fmt(tp['entry_price_eur'] as double? ?? 0.0));
    _stopCtrl = TextEditingController(
        text: _fmt(tp['stop_level_eur'] as double? ?? 0.0));
    _atrCtrl  = TextEditingController(
        text: _fmt(tp['atr_eur'] as double? ?? 0.0));

    for (final c in [_qtyCtrl, _fillCtrl, _stopCtrl, _atrCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _fillCtrl.dispose();
    _stopCtrl.dispose();
    _atrCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) => v.toStringAsFixed(2);

  int get _qty => int.tryParse(_qtyCtrl.text) ?? 0;
  double get _fill => double.tryParse(_fillCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _stop => double.tryParse(_stopCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _atr  => double.tryParse(_atrCtrl.text.replaceAll(',', '.')) ?? 0;

  double get _volume => _qty > 0 && _fill > 0 ? _qty * _fill : 0;
  bool get _budgetOk => _volume > 0 && _volume <= widget.availableBudgetEur;
  bool get _formValid =>
      _qty > 0 && _fill > 0 && _stop > 0 && _atr > 0 && _budgetOk;

  Future<void> _submit() async {
    if (!_formValid) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.postBought(
        ticker: widget.candidate['ticker'] as String,
        quantity: _qty,
        fillPriceEur: _fill,
        stopEur: _stop,
        atrEur: _atr,
        notes: widget.candidate['katalysator'] as String? ?? '',
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

  @override
  Widget build(BuildContext context) {
    final ticker = widget.candidate['ticker'] as String? ?? '–';
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: KestrelColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: KestrelColors.gold, width: 2),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Row(children: [
              Text(
                'KAUF BESTÄTIGEN',
                style: TextStyle(
                  color: KestrelColors.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                ticker,
                style: const TextStyle(
                  color: KestrelColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Felder ──────────────────────────────────────────
            Row(children: [
              Expanded(child: _Field(
                label: 'STÜCKZAHL',
                controller: _qtyCtrl,
                isInteger: true,
              )),
              const SizedBox(width: 12),
              Expanded(child: _Field(
                label: 'FILL-KURS (€)',
                controller: _fillCtrl,
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Field(
                label: 'STOP (€)',
                controller: _stopCtrl,
              )),
              const SizedBox(width: 12),
              Expanded(child: _Field(
                label: 'ATR (€)',
                controller: _atrCtrl,
              )),
            ]),
            const SizedBox(height: 16),

            // ── Volumen-Zusammenfassung ──────────────────────────
            _VolumeSummary(
              volume: _volume,
              availableBudget: widget.availableBudgetEur,
              qty: _qty,
              fill: _fill,
            ),

            // ── Fehler ──────────────────────────────────────────
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

            // ── Buttons ─────────────────────────────────────────
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
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
                    backgroundColor: KestrelColors.gold,
                    disabledBackgroundColor:
                    KestrelColors.gold.withOpacity(0.3),
                    foregroundColor: const Color(0xFF0F1822),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0F1822),
                    ),
                  )
                      : const Text(
                    'Kauf erfassen',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Volumen-Zusammenfassung ────────────────────────────────────

class _VolumeSummary extends StatelessWidget {
  final double volume;
  final double availableBudget;
  final int qty;
  final double fill;

  const _VolumeSummary({
    required this.volume,
    required this.availableBudget,
    required this.qty,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    final budgetOk = volume > 0 && volume <= availableBudget;
    final color = volume == 0
        ? KestrelColors.textDimmed
        : budgetOk
        ? KestrelColors.green
        : KestrelColors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: KestrelColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: volume == 0
              ? KestrelColors.cardBorder
              : budgetOk
              ? KestrelColors.green.withOpacity(0.4)
              : KestrelColors.red.withOpacity(0.4),
        ),
      ),
      child: Row(children: [
        Text(
          'Volumen',
          style: TextStyle(
            color: KestrelColors.textDimmed,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        if (qty > 0 && fill > 0)
          Text(
            '$qty × €${fill.toStringAsFixed(2)} = ',
            style: const TextStyle(
              color: KestrelColors.textDimmed,
              fontSize: 12,
            ),
          ),
        Text(
          volume > 0 ? '€${volume.toStringAsFixed(2)}' : '–',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (!budgetOk && volume > 0) ...[
          const SizedBox(width: 6),
          Text(
            '(max €${availableBudget.toStringAsFixed(0)})',
            style: const TextStyle(
              color: KestrelColors.red,
              fontSize: 10,
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Eingabefeld ────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isInteger;

  const _Field({
    required this.label,
    required this.controller,
    this.isInteger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: KestrelColors.gold,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: isInteger
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: isInteger
              ? [FilteringTextInputFormatter.digitsOnly]
              : [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
          style: const TextStyle(
            color: KestrelColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: KestrelColors.screenBg,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
          ),
        ),
      ],
    );
  }
}