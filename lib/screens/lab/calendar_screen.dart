import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/kestrel_theme.dart';

enum _CalFilter { all, positions, shortlist }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  _CalFilter    _filter  = _CalFilter.all;
  bool          _loading = true;
  String?       _error;
  List<dynamic> _days    = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final filterStr = switch (_filter) {
        _CalFilter.positions => 'positions',
        _CalFilter.shortlist => 'shortlist',
        _CalFilter.all       => 'all',
      };
      final data = await ApiService.getCalendar(filter: filterStr);
      setState(() {
        _days    = (data['days'] as List? ?? []);
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
    return Column(
      children: [
        _FilterRow(
          current:  _filter,
          onChange: (f) {
            setState(() => _filter = f);
            _load();
          },
        ),
        Expanded(
          child: _loading
              ? const Center(
              child: CircularProgressIndicator(color: KestrelColors.gold))
              : _error != null
              ? _ErrorState(message: _error!)
              : _days.isEmpty
              ? _EmptyState(filter: _filter)
              : RefreshIndicator(
            color:     KestrelColors.gold,
            onRefresh: _load,
            child: ListView.builder(
              padding:     const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount:   _days.length,
              itemBuilder: (_, i) =>
                  _DayGroup(day: _days[i] as Map<String, dynamic>),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Filter Row ─────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final _CalFilter current;
  final ValueChanged<_CalFilter> onChange;
  const _FilterRow({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KestrelColors.cardBorder)),
      ),
      child: Row(
        children: [
          _Pill(
            label:  'Alle',
            active: current == _CalFilter.all,
            onTap:  () => onChange(_CalFilter.all),
          ),
          const SizedBox(width: 8),
          _Pill(
            label:  'Positionen',
            active: current == _CalFilter.positions,
            onTap:  () => onChange(_CalFilter.positions),
          ),
          const SizedBox(width: 8),
          _Pill(
            label:  'Shortlist',
            active: current == _CalFilter.shortlist,
            onTap:  () => onChange(_CalFilter.shortlist),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color:        active ? KestrelColors.goldBg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? KestrelColors.goldBorder : KestrelColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize:   12,
            color:      active ? KestrelColors.gold : KestrelColors.textGrey,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Day Group ──────────────────────────────────────────────────

class _DayGroup extends StatelessWidget {
  final Map<String, dynamic> day;
  const _DayGroup({required this.day});

  @override
  Widget build(BuildContext context) {
    final label      = day['label']   as String? ?? day['date'] as String? ?? '';
    final entries    = (day['entries'] as List? ?? []).cast<Map<String, dynamic>>();
    final relevant   = entries.where((e) => e['tag'] != 'universe').toList();
    final universe   = entries.where((e) => e['tag'] == 'universe').toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DayHeader(label: label, count: entries.length),
          const SizedBox(height: 6),
          // Positions + Shortlist als vollständige Cards
          ...relevant.map((e) => _EntryCard(entry: e)),
          // Universe als kompakte Chip-Zeile
          if (universe.isNotEmpty)
            _UniverseChips(entries: universe),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  final int count;
  const _DayHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width:  6,
          height: 6,
          decoration: const BoxDecoration(
            color: KestrelColors.gold,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: KestrelColors.textGrey, fontSize: 12)),
        const Spacer(),
        Text('$count Berichte',
            style: const TextStyle(
                color: KestrelColors.textDimmed, fontSize: 11)),
      ],
    );
  }
}

// ── Universe Chips ─────────────────────────────────────────────

class _UniverseChips extends StatefulWidget {
  final List<Map<String, dynamic>> entries;
  const _UniverseChips({required this.entries});

  @override
  State<_UniverseChips> createState() => _UniverseChipsState();
}

class _UniverseChipsState extends State<_UniverseChips> {
  static const int _maxVisible = 12;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tickers   = widget.entries.map((e) => e['ticker'] as String? ?? '').toList();
    final visible   = _expanded ? tickers : tickers.take(_maxVisible).toList();
    final overflow  = tickers.length - _maxVisible;

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color:        KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: KestrelColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UNIVERSUM',
            style: TextStyle(
              color:         KestrelColors.textDimmed,
              fontSize:      9,
              fontWeight:    FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing:   6,
            runSpacing: 5,
            children: [
              ...visible.map((t) => _TickerChip(ticker: t)),
              if (!_expanded && overflow > 0)
                GestureDetector(
                  onTap: () => setState(() => _expanded = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:        KestrelColors.screenBg,
                      borderRadius: BorderRadius.circular(5),
                      border:       Border.all(
                          color: KestrelColors.cardBorder,
                          style: BorderStyle.solid),
                    ),
                    child: Text(
                      '+$overflow',
                      style: const TextStyle(
                        color:      KestrelColors.textDimmed,
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (_expanded)
                GestureDetector(
                  onTap: () => setState(() => _expanded = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:        KestrelColors.screenBg,
                      borderRadius: BorderRadius.circular(5),
                      border:       Border.all(color: KestrelColors.cardBorder),
                    ),
                    child: const Text(
                      'Weniger',
                      style: TextStyle(
                        color:      KestrelColors.textDimmed,
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TickerChip extends StatelessWidget {
  final String ticker;
  const _TickerChip({required this.ticker});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:        KestrelColors.screenBg,
        borderRadius: BorderRadius.circular(5),
        border:       Border.all(color: KestrelColors.cardBorder, width: 0.5),
      ),
      child: Text(
        ticker,
        style: const TextStyle(
          color:      KestrelColors.textPrimary,
          fontSize:   11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Entry Card (Position / Shortlist) ──────────────────────────

class _EntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final ticker  = entry['ticker']          as String? ?? '';
    final company = entry['company']         as String? ?? ticker;
    final tag     = entry['tag']             as String? ?? 'universe';
    final time    = entry['time']            as String? ?? '--';
    final locked  = entry['earnings_locked'] as bool?   ?? false;

    final accentColor = tag == 'position'
        ? KestrelColors.gold
        : KestrelColors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color:        KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left:   BorderSide(color: accentColor, width: 2),
          top:    const BorderSide(color: KestrelColors.cardBorder, width: 0.5),
          right:  const BorderSide(color: KestrelColors.cardBorder, width: 0.5),
          bottom: const BorderSide(color: KestrelColors.cardBorder, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(ticker,
                          style: const TextStyle(
                              color:      KestrelColors.textPrimary,
                              fontSize:   14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      _TagBadge(tag: tag),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        _LockChip(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    company,
                    style: const TextStyle(
                        color: KestrelColors.textGrey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _TimeChip(time: time),
          ],
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String tag;
  const _TagBadge({required this.tag});

  @override
  Widget build(BuildContext context) {
    if (tag == 'universe') return const SizedBox.shrink();
    final isPosition = tag == 'position';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        isPosition ? KestrelColors.goldBg : KestrelColors.greenBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isPosition ? KestrelColors.goldBorder : KestrelColors.greenBorder,
        ),
      ),
      child: Text(
        isPosition ? 'Position' : 'Shortlist',
        style: TextStyle(
          color:         isPosition ? KestrelColors.gold : KestrelColors.green,
          fontSize:      9,
          fontWeight:    FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _LockChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        KestrelColors.goldBg,
        borderRadius: BorderRadius.circular(4),
        border:       Border.all(color: KestrelColors.goldBorder),
      ),
      child: const Text(
        'Sperre aktiv',
        style: TextStyle(
            color:      KestrelColors.gold,
            fontSize:   9,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String time;
  const _TimeChip({required this.time});

  @override
  Widget build(BuildContext context) {
    return Text(
      time.toUpperCase(),
      style: const TextStyle(
          color:         KestrelColors.textDimmed,
          fontSize:      11,
          letterSpacing: 0.4),
    );
  }
}

// ── States ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _CalFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (filter) {
      _CalFilter.positions => (
      Icons.check_circle_outline,
      'Keine bevorstehenden Earnings',
      'Deine offenen Positionen haben\nkeine Earnings in den nächsten 14 Tagen.',
      ),
      _CalFilter.shortlist => (
      Icons.playlist_remove,
      'Shortlist hat keine Earnings',
      'Keine Shortlist-Kandidaten mit\nbevorstehenden Earnings gefunden.',
      ),
      _CalFilter.all => (
      Icons.event_busy_outlined,
      'Keine Earnings',
      'Keine Berichte in den nächsten 14 Tagen.',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: KestrelColors.textDimmed, size: 40),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color:      KestrelColors.textPrimary,
                fontSize:   15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color:    KestrelColors.textGrey,
                fontSize: 13,
                height:   1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: const TextStyle(color: KestrelColors.textGrey, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}