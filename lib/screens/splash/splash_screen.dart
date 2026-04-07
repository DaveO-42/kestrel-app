import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnim;

  // Gecachte Daten die nach dem Splash an MainScreen übergeben werden
  Map<String, dynamic>? _dashboardData;
  String? _loadError;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );

    _runSequence();
  }

  Future<void> _setProgress(double target, {int ms = 400}) async {
    _progressAnim = Tween<double>(
      begin: _progressAnim.value,
      end: target,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));
    _progressController
      ..reset()
      ..forward();
    await Future.delayed(Duration(milliseconds: ms));
  }

  Future<void> _runSequence() async {
    // Stufe 1: App gestartet
    await _setProgress(0.4, ms: 500);

    // Stufe 2: API-Call
    try {
      _dashboardData = await ApiService.getDashboard();
    } catch (e) {
      _loadError = e.toString();
    }

    // Stufe 3: Daten da → 100%
    await _setProgress(1.0, ms: 300);

    // Kurze Pause damit 100% sichtbar ist
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    // Übergang zu MainScreen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            MainScreen(preloadedDashboard: _dashboardData),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              KestrelLogo(size: 64),
              const SizedBox(height: 20),
              // App-Name
              const Text(
                'KESTREL',
                style: TextStyle(
                  color: KestrelColors.goldLight,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 48),
              // Fortschrittsbalken
              _ProgressBar(animation: _progressAnim),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animierter Fortschrittsbalken ─────────────────────────────

class _ProgressBar extends StatelessWidget {
  final Animation<double> animation;
  const _ProgressBar({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: KestrelColors.cardBorder,
            borderRadius: BorderRadius.circular(2),
          ),
          child: AnimatedBuilder(
            animation: animation,
            builder: (_, __) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: animation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: KestrelColors.gold,
                  borderRadius: BorderRadius.circular(2),
                  // Leucht-Effekt am Ende des Balkens
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x80C9A84C),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}