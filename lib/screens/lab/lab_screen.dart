import 'package:flutter/material.dart';
import '../../theme/kestrel_theme.dart';
import 'sandbox_screen.dart';
import 'setups_screen.dart';
import 'paper_tab.dart';
import '../../main_screen.dart';
import '../../widgets/offline_banner.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  int _selectedIndex = 0;
  final _setupsKey = GlobalKey<SetupsScreenState>();
  bool _infoOpen = false;

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xBF060A10),
      builder: (_) => const _LabInfoSheet(),
    ).then((_) {
      if (mounted) setState(() => _infoOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: AppBar(
        backgroundColor:  KestrelColors.appBarBg,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        titleSpacing:     13,
        title: Row(
          children: [
            KestrelLogo(size: 26),
            const SizedBox(width: 8),
            const Text(
              'Lab',
              style: TextStyle(
                color:         KestrelColors.goldLight,
                fontSize:      16,
                fontWeight:    FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          InfoButton(active: _infoOpen, onTap: () => _showInfoSheet(context)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: KestrelColors.cardBorder),
        ),
      ),
      body: Column(
        children: [
          if (KestrelNav.of(context)?.connectionError == true)
            const OfflineBanner(),
          _SegmentedControl(
            selectedIndex: _selectedIndex,
            onChanged: (i) {
              setState(() => _selectedIndex = i);
              if (i == 1) {
                _setupsKey.currentState?.reload();
              }
            },
            labels: const ['Sandbox', 'Setups', 'Paper'],
          ),
          Container(height: 1, color: KestrelColors.cardBorder),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                const SandboxScreen(),
                SetupsScreen(key: _setupsKey),
                const PaperTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Segmented Control ──────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<String> labels;
  const _SegmentedControl({
    required this.selectedIndex,
    required this.onChanged,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KestrelColors.appBarBg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color:        KestrelColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border:       Border.all(color: KestrelColors.cardBorder),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(height: 2, color: KestrelColors.gold),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 5, 3, 3),
                child: Row(
                  children: List.generate(labels.length, (i) {
                    final active = i == selectedIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onChanged(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color:        active ? KestrelColors.gold : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          alignment: Alignment.center,
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              color:      active ? KestrelColors.appBarBg : KestrelColors.textGrey,
                              fontSize:   13,
                              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabInfoSheet extends StatelessWidget {
  const _LabInfoSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize:     0.92,
      minChildSize:     0.4,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1623),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: Color(0xFF1E2E42))),
        ),
        child: Column(
          children: [
            // Drag Handle
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 28, height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2E42),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Column(
                      children: [
                        KestrelLogo(size: 60),
                        const SizedBox(height: 6),
                        const Text('Lab', style: TextStyle(
                          color:         KestrelColors.goldLight,
                          fontSize:      14,
                          fontWeight:    FontWeight.w700,
                          letterSpacing: 2,
                        )),
                        const SizedBox(height: 2),
                        const Text('SANDBOX · SETUP', style: TextStyle(
                          color:         Color(0xFF8A6E2A),
                          fontSize:      10,
                          letterSpacing: 1.5,
                        )),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color:  const Color(0xFF141F2E),
                          shape:  BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1E2E42)),
                        ),
                        child: const Center(
                          child: Icon(Icons.close,
                              color: KestrelColors.textDimmed, size: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFF141F2E)),

            // Scrollbarer Inhalt
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                      left: 16, right: 16, top: 20,
                      bottom: 32 + MediaQuery.of(context).padding.bottom),
                  children: const [
                    _InfoSection(
                      title:   'BASELINE',
                      content: 'Die Baseline sind die Produktionsparameter des '
                          'laufenden Systems (ATR×2.0 · RSI 50–70 · Perf >3%). '
                          'Sie dienen als Referenz für jeden Vergleich. Der '
                          'Strich auf dem Slider zeigt die Baseline-Position.',
                    ),
                    _InfoSection(
                      title: 'FARBCODIERUNG',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ColorRow(
                              color: KestrelColors.green,
                              label: 'Besser als Baseline'),
                          SizedBox(height: 6),
                          _ColorRow(
                              color: KestrelColors.red,
                              label: 'Schlechter als Baseline'),
                          SizedBox(height: 6),
                          _ColorRow(
                              color: KestrelColors.gold,
                              label: 'Identisch mit Baseline'),
                        ],
                      ),
                    ),
                    _InfoSection(
                      title: 'PARAMETER',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ParamRow(
                            param: 'ATR-Multiplikator',
                            desc:  'Bestimmt die Stop-Distanz. '
                                'Kleiner = engerer Stop = mehr Trades ausgestoppt.',
                          ),
                          SizedBox(height: 8),
                          _ParamRow(
                            param: 'RSI-Bereich',
                            desc:  'Entry nur wenn RSI in diesem Bereich liegt. '
                                'Zu eng = weniger Trades, zu weit = mehr Fehlsignale.',
                          ),
                          SizedBox(height: 8),
                          _ParamRow(
                            param: 'Min. Performance',
                            desc:  'Mindest-Kursgewinn seit Earnings-Beat bis Entry. '
                                'Höher = stärkere Momentum-Bestätigung.',
                          ),
                        ],
                      ),
                    ),
                    _InfoSection(
                      title:   'ZEITRÄUME',
                      content: '2022–2024 sind statistisch aussagekräftig. '
                          '2025 ist durch den Zoll-Schock (April 2025) ein Ausreißer – '
                          '72 Trades bei 31.9% Win-Rate. Als Testjahr nur bedingt '
                          'geeignet.',
                    ),
                    _InfoSection(
                      title:   'SETUP',
                      content: 'Gespeicherte Konfigurationen können verglichen werden. '
                          'Zwei auswählen → Vergleich erscheint automatisch. '
                          'Die schlechtere Konfiguration löschen und weiter optimieren.',
                    ),
                    _InfoSection(
                      title:   'HINWEIS',
                      content: 'Der Backtest hat Survivorship Bias – nur Aktien die heute '
                          'noch existieren werden getestet. Die Ergebnisse sind '
                          'Orientierungswerte, keine Garantien. '
                          'Parameteränderungen am Live-System erst nach dem '
                          '30-Trade-Review.',
                      isLast:  true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hilfs-Widgets für das InfoSheet ───────────────────────────

class _InfoSection extends StatelessWidget {
  final String  title;
  final String? content;
  final Widget? child;
  final bool    isLast;
  const _InfoSection({
    required this.title,
    this.content,
    this.child,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(
          color:         KestrelColors.gold,
          fontSize:      11,
          fontWeight:    FontWeight.w700,
          letterSpacing: 0.8,
        )),
        const SizedBox(height: 8),
        if (content != null)
          Text(content!, style: const TextStyle(
              color: KestrelColors.textGrey, fontSize: 12, height: 1.5)),
        if (child != null) child!,
        if (!isLast) ...[
          const SizedBox(height: 16),
          Container(height: 1, color: KestrelColors.cardBorder),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  final Color  color;
  final String label;
  const _ColorRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(
            color: KestrelColors.textGrey, fontSize: 12)),
      ],
    );
  }
}

class _ParamRow extends StatelessWidget {
  final String param, desc;
  const _ParamRow({required this.param, required this.desc});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$param: ',
            style: const TextStyle(
              color:      KestrelColors.textPrimary,
              fontSize:   12,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: desc,
            style: const TextStyle(
              color:    KestrelColors.textGrey,
              fontSize: 12,
              height:   1.5,
            ),
          ),
        ],
      ),
    );
  }
}
