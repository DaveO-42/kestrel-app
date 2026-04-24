import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/login/login_screen.dart';
import 'theme/kestrel_theme.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/shortlist/shortlist_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/system/system_screen.dart';

// ── KestrelNav – InheritedWidget ──────────────────────────────
// Stellt app-weite Callbacks bereit:

class KestrelNav extends InheritedWidget {
  final VoidCallback goToDashboard;
  final VoidCallback goToSystem;
  final VoidCallback goToHistory;
  final VoidCallback goToSettings;
  final VoidCallback refreshDashboard;
  final ValueChanged<bool> setConnectionError;
  final ValueChanged<int> goToTab;
  final bool connectionError;

  const KestrelNav({
    super.key,
    required this.goToDashboard,
    required this.goToSystem,
    required this.goToHistory,
    required this.goToSettings,
    required this.refreshDashboard,
    required this.setConnectionError,
    required this.goToTab,
    required this.connectionError,
    required super.child,
  });

  static KestrelNav? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<KestrelNav>();
  }

  @override
  bool updateShouldNotify(KestrelNav old) =>
      connectionError != old.connectionError ||
          goToDashboard != old.goToDashboard ||
          goToSystem != old.goToSystem ||
          goToHistory != old.goToHistory ||
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
  final _dashboardRefresh = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    ApiService.onAuthError = _navigateToLogin;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().init(context);
    });
  }

  @override
  void dispose() {
    ApiService.onAuthError = null;
    _dashboardRefresh.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return KestrelNav(
      goToDashboard:      () => setState(() => _index = 0),
      goToSystem:         () => setState(() => _index = 3),
      goToHistory:        () => setState(() => _index = 2),
      goToSettings:       _openSettings,
      refreshDashboard:   () => _dashboardRefresh.value++,
      setConnectionError: (v) => setState(() => _connError = v),
      goToTab:            (i) => setState(() => _index = i),
      connectionError:    _connError,
      child: Scaffold(
        backgroundColor: KestrelColors.screenBg,
        body: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(refreshNotifier: _dashboardRefresh),
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
              _NavItem(icon: Icons.history,      label: 'History',   active: currentIndex == 2, onTap: () => onTap(2)),
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
            Icon(icon, color: color, size: 25),
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

  // Server-URL
  late TextEditingController _urlController;
  bool _urlDirty = false;

  // Benachrichtigungen
  bool _notifShortlist  = false;
  bool _notifWarn       = false;
  bool _notifHard       = false;

  bool _shutdownLoading = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiService.baseUrl);
    _loadVersions();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadVersions() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifShortlist = prefs.getBool('notif_shortlist') ?? false;
      _notifWarn      = prefs.getBool('notif_warn')      ?? false;
      _notifHard      = prefs.getBool('notif_hard')      ?? false;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _connStatus  = _ConnStatus.testing;
      _connMessage = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      await ApiService.testConnection();
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

  Future<void> _saveUrl() async {
    final newUrl = _urlController.text.trim();
    if (newUrl.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', newUrl);
    ApiService.baseUrl = newUrl;
    if (!mounted) return;
    setState(() => _urlDirty = false);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Server-URL gespeichert. Verbindungstest empfohlen.'),
    ));
  }

  Future<void> _onNotifToggle(String key, String topic, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (!mounted) return;
    setState(() {
      if (key == 'notif_shortlist') _notifShortlist = value;
      if (key == 'notif_warn')      _notifWarn      = value;
      if (key == 'notif_hard')      _notifHard      = value;
    });

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Benachrichtigungen in den System-Einstellungen blockiert.'),
        ));
      }
      return;
    }

    if (value) {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    }
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
          icon: const Icon(Icons.arrow_back,
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
                    TextField(
                      controller: _urlController,
                      style: const TextStyle(
                        color: KestrelColors.textGrey,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: KestrelColors.screenBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: KestrelColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: KestrelColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: KestrelColors.gold),
                        ),
                        suffixIcon: _urlDirty
                            ? IconButton(
                                icon: const Icon(Icons.check,
                                    color: KestrelColors.gold, size: 16),
                                onPressed: _saveUrl,
                              )
                            : null,
                      ),
                      onChanged: (v) =>
                          setState(() => _urlDirty = v != ApiService.baseUrl),
                      onSubmitted: (_) => _saveUrl(),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
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
                sub: 'Neuer Kandidat nach Run',
                value: _notifShortlist,
                onChanged: (v) =>
                    _onNotifToggle('notif_shortlist', 'kestrel_candidates', v),
              ),
              _ToggleRow(
                label: 'WARN-Signal',
                sub: 'Trendumkehr erkannt',
                value: _notifWarn,
                onChanged: (v) =>
                    _onNotifToggle('notif_warn', 'kestrel_warn', v),
              ),
              _ToggleRow(
                label: 'HARD-Signal',
                sub: 'Sofortiger Handlungsbedarf',
                value: _notifHard,
                onChanged: (v) =>
                    _onNotifToggle('notif_hard', 'kestrel_hard', v),
              ),
            ],
          ),

          // ── Account ──────────────────────────────────────
          _SectionHeader(label: 'Account'),
          _SettingsCard(
            children: [
              GestureDetector(
                onTap: _logout,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: KestrelColors.red, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Abmelden',
                                style: TextStyle(
                                    color: KestrelColors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            SizedBox(height: 2),
                            Text('Kestrel-Sitzung beenden',
                                style: TextStyle(
                                    color: KestrelColors.textDimmed,
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: KestrelColors.cardBorder, indent: 13),
              GestureDetector(
                onTap: _shutdownLoading ? null : _handleShutdown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                  child: Row(
                    children: [
                      _shutdownLoading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: KestrelColors.red))
                          : const Icon(Icons.power_settings_new,
                              color: KestrelColors.red, size: 16),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pi herunterfahren',
                                style: TextStyle(
                                    color: KestrelColors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            SizedBox(height: 2),
                            Text('Fährt den Raspberry Pi sauber herunter',
                                style: TextStyle(
                                    color: KestrelColors.textDimmed,
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Future<void> _handleShutdown() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: KestrelColors.cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: KestrelColors.cardBorder)),
        title: const Text('Pi herunterfahren?',
            style: TextStyle(color: KestrelColors.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: const Text(
          'Der Pi wird heruntergefahren. Die App verliert die Verbindung.',
          style: TextStyle(color: KestrelColors.textGrey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: KestrelColors.textDimmed)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Herunterfahren',
                style: TextStyle(color: KestrelColors.red,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _shutdownLoading = true);
    try {
      await ApiService.postShutdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Shutdown eingeleitet – Verbindung wird getrennt.'),
          duration: Duration(seconds: 4),
        ));
      }
    } on ActionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: KestrelColors.red,
          duration: const Duration(seconds: 3),
        ));
      }
    } finally {
      if (mounted) setState(() => _shutdownLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KestrelColors.cardBg,
        title: const Text(
          'Abmelden',
          style: TextStyle(color: KestrelColors.textPrimary),
        ),
        content: const Text(
          'Wirklich abmelden?',
          style: TextStyle(color: KestrelColors.textDimmed),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: KestrelColors.textDimmed)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abmelden',
                style: TextStyle(color: KestrelColors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
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
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

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
                Text(label,
                    style: const TextStyle(
                        color: KestrelColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        color: KestrelColors.textDimmed, fontSize: 10)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: KestrelColors.gold,
            inactiveThumbColor: KestrelColors.textDimmed,
            inactiveTrackColor: KestrelColors.cardBorder,
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
        Icons.help_outline,
        color: active ? KestrelColors.gold : KestrelColors.textGrey,
        size: 20,
      ),
      onPressed: onTap,
    );
  }
}