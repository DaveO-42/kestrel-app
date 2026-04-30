import 'package:flutter/material.dart';
import '../../theme/kestrel_theme.dart';
import 'sandbox_screen.dart';
import 'calendar_screen.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  int _selectedIndex = 0;

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: KestrelColors.cardBorder),
        ),
      ),
      body: Column(
        children: [
          _SegmentedControl(
            selectedIndex: _selectedIndex,
            onChanged: (i) => setState(() => _selectedIndex = i),
            labels: const ['Sandbox', 'Kalender'],
          ),
          Container(height: 1, color: KestrelColors.cardBorder),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                SandboxScreen(),
                CalendarScreen(),
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
      child: Container(
        decoration: BoxDecoration(
          color:        KestrelColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: KestrelColors.cardBorder),
        ),
        padding: const EdgeInsets.all(3),
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
    );
  }
}
