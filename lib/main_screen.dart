import 'package:flutter/material.dart';
import 'theme/kestrel_theme.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/shortlist/shortlist_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/system/system_screen.dart';

// ── KestrelNav – InheritedWidget ──────────────────────────────
// Macht Tab-Navigation für jeden Screen erreichbar:
//   KestrelNav.of(context).goToSystem()

class KestrelNav extends InheritedWidget {
  final VoidCallback goToSystem;

  const KestrelNav({
    super.key,
    required this.goToSystem,
    required super.child,
  });

  static KestrelNav? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<KestrelNav>();
  }

  @override
  bool updateShouldNotify(KestrelNav oldWidget) =>
      goToSystem != oldWidget.goToSystem;
}

// ── Navigation Shell ──────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return KestrelNav(
      goToSystem: () => setState(() => _index = 3),
      child: Scaffold(
        backgroundColor: KestrelColors.screenBg,
        body: IndexedStack(
          index: _index,
          children: const [
            DashboardScreen(),
            ShortlistScreen(),
            HistoryScreen(),
            SystemScreen(),
          ],
        ),
        bottomNavigationBar: _KestrelNavBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

// ── Nav Bar ───────────────────────────────────────────────────

class _KestrelNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _KestrelNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KestrelColors.appBarBg,
        border: Border(top: BorderSide(color: KestrelColors.cardBorder)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', active: currentIndex == 0, onTap: () => onTap(0)),
              _NavItem(icon: Icons.list_alt_outlined,  label: 'Shortlist',  active: currentIndex == 1, onTap: () => onTap(1)),
              _NavItem(icon: Icons.bar_chart_outlined, label: 'History',    active: currentIndex == 2, onTap: () => onTap(2)),
              _NavItem(icon: Icons.person_outline,     label: 'System',     active: currentIndex == 3, onTap: () => onTap(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? KestrelColors.gold : KestrelColors.textHint;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Pause Banner Widget ───────────────────────────────────────
// Auf jedem Screen einbinden wenn system['paused'] == true.
// Tap navigiert zum System-Tab via KestrelNav.

class PauseBanner extends StatelessWidget {
  final String? reason;
  final num? drawdownPct;
  const PauseBanner({super.key, this.reason, this.drawdownPct});

  @override
  Widget build(BuildContext context) {
    final label = drawdownPct != null
        ? 'System pausiert · Drawdown ${drawdownPct!.toStringAsFixed(1).replaceAll('.', ',')} %'
        : reason ?? 'System pausiert';

    return GestureDetector(
      onTap: () => KestrelNav.of(context)?.goToSystem(),
      child: Container(
        width: double.infinity,
        color: const Color(0xFF1E0808),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: KestrelColors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const Text('→ System',
                style: TextStyle(
                    color: KestrelColors.red, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}