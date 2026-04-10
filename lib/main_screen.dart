import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'theme/kestrel_theme.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/shortlist/shortlist_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/system/system_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ── KestrelNav – InheritedWidget ──────────────────────────────
// Stellt app-weite Callbacks bereit:
//   KestrelNav.of(context)?.goToSystem()
//   KestrelNav.of(context)?.goToSettings()
//   KestrelNav.of(context)?.setConnectionError(true/false)
//   KestrelNav.of(context)?.connectionError  → bool

class KestrelNav extends InheritedWidget {
  final VoidCallback goToSystem;
  final VoidCallback goToSettings;
  final ValueChanged<bool> setConnectionError;
  final bool connectionError;

  const KestrelNav({
    super.key,
    required this.goToSystem,
    required this.goToSettings,
    required this.setConnectionError,
    required this.connectionError,
    required super.child,
  });

  static KestrelNav? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<KestrelNav>();
  }

  @override
  bool updateShouldNotify(KestrelNav old) =>
      connectionError != old.connectionError ||
          goToSystem != old.goToSystem ||
          goToSettings != old.goToSettings;
}

// ── Main Screen ───────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index          = 0;
  bool _connError     = false;

  @override
  Widget build(BuildContext context) {
    return KestrelNav(
      goToSystem:         () => setState(() => _index = 3),
      goToSettings:       _openSettings,
      setConnectionError: (v) => setState(() => _connError = v),
      connectionError:    _connError,
      child: Scaffold(
        backgroundColor: KestrelColors.screenBg,
        body: IndexedStack(
          index: _index,
          children: [
            const DashboardScreen(),
            const ShortlistScreen(),
            const HistoryScreen(),
            const SystemScreen(),
          ],
        ),
        bottomNavigationBar: _KestrelNavBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (result != null) {
      setState(() => _connError = result);
    }
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
              _NavItem(icon: Icons.dashboard_outlined,    label: 'Dashboard', active: currentIndex == 0, onTap: () => onTap(0)),
              _NavItem(icon: Icons.list_alt_outlined,     label: 'Shortlist', active: currentIndex == 1, onTap: () => onTap(1)),
              _NavItem(icon: Icons.storage_outlined,      label: 'History',   active: currentIndex == 2, onTap: () => onTap(2)),
              _NavItem(icon: Icons.monitor_heart_outlined,label: 'Status',    active: currentIndex == 3, onTap: () => onTap(3)),
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
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? KestrelColors.gold : KestrelColors.textGrey;
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

// ── Pause Banner ──────────────────────────────────────────────

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
            Text(
              label,
              style: const TextStyle(
                color: KestrelColors.red,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              '→ System',
              style: TextStyle(color: KestrelColors.red, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error Banner (schmaler roter Streifen, alle Screens außer Dashboard) ──

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E0808),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: KestrelColors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Keine Verbindung',
              style: TextStyle(
                color: KestrelColors.red,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => KestrelNav.of(context)?.goToSettings(),
            child: const Text(
              '↑ Settings',
              style: TextStyle(
                color: KestrelColors.red,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings Screen ───────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  _ConnStatus _connStatus = _ConnStatus.idle;
  String? _connMessage;
  String? _connTimestamp;
  bool? _lastConnError;

  // Versionen
  String _appVersion     = '…';
  String _apiVersion     = '…';
  String _backendVersion = '…';

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    final info     = await PackageInfo.fromPlatform();
    final versions = await ApiService.getVersion();
    if (!mounted) return;
    setState(() {
      _appVersion     = info.version;
      _apiVersion     = versions?['api']     as String? ?? '–';
      _backendVersion = versions?['backend'] as String? ?? '–';
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _connStatus  = _ConnStatus.testing;
      _connMessage = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final result = await ApiService.testConnection();
      stopwatch.stop();
      final ms = stopwatch.elapsedMilliseconds;
      setState(() {
        _connStatus  = _ConnStatus.ok;
        _connMessage = 'Verbunden · ${ms}ms';
        _connTimestamp = _nowTime();
      });
      _lastConnError = false;
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _connStatus  = _ConnStatus.error;
        _connMessage = 'Nicht erreichbar';
        _connTimestamp = _nowTime();
      });
      _lastConnError = true;
    }
  }

  String _nowTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      appBar: AppBar(
        backgroundColor: KestrelColors.appBarBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: KestrelColors.textDimmed, size: 18),
          onPressed: () => Navigator.pop(context, _lastConnError),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            KestrelLogo(size: 22),
            const SizedBox(width: 8),
            const Text(
              'Settings',
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
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // ── Verbindung ──────────────────────────────────
          _SectionHeader(label: 'Verbindung'),
          _SettingsCard(
            children: [
              _SettingsRow(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Server-URL', style: _labelStyle),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: KestrelColors.screenBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: KestrelColors.cardBorder),
                      ),
                      child: Text(
                        ApiService.baseUrl,
                        style: const TextStyle(
                          color: KestrelColors.textGrey,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _SettingsRow(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Test-Button
                    GestureDetector(
                      onTap: _connStatus == _ConnStatus.testing
                          ? null
                          : _testConnection,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border:
                          Border.all(color: KestrelColors.cardBorder),
                        ),
                        alignment: Alignment.center,
                        child: _connStatus == _ConnStatus.testing
                            ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: KestrelColors.gold,
                            strokeWidth: 1.5,
                          ),
                        )
                            : const Text(
                          'Verbindung testen',
                          style: TextStyle(
                            color: KestrelColors.textGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Ergebnis
                    if (_connMessage != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: KestrelColors.screenBg,
                          borderRadius: BorderRadius.circular(7),
                          border:
                          Border.all(color: KestrelColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _connStatus == _ConnStatus.ok
                                    ? KestrelColors.green
                                    : KestrelColors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _connMessage!,
                              style: TextStyle(
                                color: _connStatus == _ConnStatus.ok
                                    ? KestrelColors.green
                                    : KestrelColors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (_connTimestamp != null)
                              Text(
                                _connTimestamp!,
                                style: const TextStyle(
                                  color: Color(0xFF334D68),
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // ── Benachrichtigungen ──────────────────────────
          _SectionHeader(label: 'Benachrichtigungen'),
          _SettingsCard(
            children: [
              _ToggleRow(
                  label: 'Shortlist verfügbar',
                  sub: 'Neuer Kandidat nach Run'),
              _ToggleRow(
                  label: 'WARN-Signal',
                  sub: 'Trendumkehr erkannt'),
              _ToggleRow(
                  label: 'HARD-Signal',
                  sub: 'Sofortiger Handlungsbedarf'),
            ],
          ),

          // ── App-Info ─────────────────────────────────────
          _SectionHeader(label: 'App-Info'),
          _SettingsCard(
            children: [
              _InfoRow(label: 'App-Version',     value: _appVersion),
              _InfoRow(label: 'API-Version',      value: _apiVersion),
              _InfoRow(label: 'Backend-Version',  value: _backendVersion),
              _InfoRow(label: 'Pi-Hostname',      value: ApiService.baseUrl.replaceAll('http://', '').replaceAll(':8000', '')),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Connection status enum ────────────────────────────────────

enum _ConnStatus { idle, testing, ok, error }

// ── Settings sub-widgets ──────────────────────────────────────

const _labelStyle = TextStyle(
  color: KestrelColors.gold,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.7,
);

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 5),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: KestrelColors.gold,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: KestrelColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KestrelColors.cardBorder),
      ),
      child: Column(
        children: children
            .asMap()
            .entries
            .map((e) => Column(
          children: [
            if (e.key > 0)
              const Divider(
                  height: 1, color: KestrelColors.cardBorder),
            e.value,
          ],
        ))
            .toList(),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final Widget child;
  const _SettingsRow({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(13),
      child: child,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String sub;
  const _ToggleRow({required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: KestrelColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    color: KestrelColors.textDimmed,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1008),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF4A3010)),
            ),
            child: const Text(
              'V2',
              style: TextStyle(
                color: Color(0xFF8A6E2A),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 7),
          // Toggle (visuell, noch nicht funktional — V2)
          Opacity(
            opacity: 0.4,
            child: Container(
              width: 30,
              height: 17,
              decoration: BoxDecoration(
                color: KestrelColors.cardBg,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: KestrelColors.cardBorder),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  width: 11,
                  height: 11,
                  decoration: const BoxDecoration(
                    color: Color(0xFF334D68),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: KestrelColors.textDimmed,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: KestrelColors.textGrey,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
class InfoButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const InfoButton({super.key, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.info_outline,
        color: active ? KestrelColors.gold : KestrelColors.textGrey,
        size: 20,
      ),
      onPressed: onTap,
    );
  }
}