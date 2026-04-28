import 'package:flutter/material.dart';
import '../../theme/kestrel_theme.dart';
import 'sandbox_screen.dart';
import 'calendar_screen.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                color:       KestrelColors.goldLight,
                fontSize:    16,
                fontWeight:  FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(41),
          child: Column(
            children: [
              _LabTabBar(controller: _tabController),
              Container(height: 1, color: KestrelColors.cardBorder),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics:    const NeverScrollableScrollPhysics(),
        children: const [
          SandboxScreen(),
          CalendarScreen(),
        ],
      ),
    );
  }
}

// ── Tab Bar ────────────────────────────────────────────────────

class _LabTabBar extends StatelessWidget {
  final TabController controller;
  const _LabTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller:       controller,
      labelColor:       KestrelColors.gold,
      unselectedLabelColor: KestrelColors.textGrey,
      labelStyle:       const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
      indicatorColor:   KestrelColors.gold,
      indicatorWeight:  2,
      indicatorSize:    TabBarIndicatorSize.label,
      dividerColor:     Colors.transparent,
      tabs: const [
        Tab(text: 'Sandbox'),
        Tab(text: 'Kalender'),
      ],
    );
  }
}