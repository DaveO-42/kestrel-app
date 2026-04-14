import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Fortschritt 0.0 → 1.0 (steuert Sonnen-Arc)
  late AnimationController _progressController;
  late Animation<double> _progressAnim;

  // FadeIn für Falke
  late AnimationController _falconFadeController;
  late Animation<double> _falconFadeAnim;

  // FadeIn für Texte
  late AnimationController _textFadeController;
  late Animation<double> _textFadeAnim;

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

    _falconFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _falconFadeAnim = CurvedAnimation(
      parent: _falconFadeController,
      curve: Curves.easeIn,
    );

    _textFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textFadeAnim = CurvedAnimation(
      parent: _textFadeController,
      curve: Curves.easeIn,
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
    // Falke einblenden
    _falconFadeController.forward();
    await Future.delayed(const Duration(milliseconds: 400));

    // Texte einblenden
    _textFadeController.forward();

    // Sonnen-Arc: 0 → 45%
    await _setProgress(0.45, ms: 500);

    // kurze Pause
    await Future.delayed(const Duration(milliseconds: 200));

    // Sonnen-Arc: 45% → 100%
    await _setProgress(1.0, ms: 400);

    // kurze Pause damit 100% sichtbar ist
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _falconFadeController.dispose();
    _textFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;

    // Sonnenkreis-Radius: ~40% der Bildschirmbreite
    final sunRadius = screenW * 0.40;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // ── Sonnen-Arc (hinter dem Falken) ──────────────────
          Positioned(
            top: screenH * 0.18,
            child: AnimatedBuilder(
              animation: _progressAnim,
              builder: (_, __) => CustomPaint(
                size: Size(sunRadius * 2, sunRadius * 2),
                painter: _SunArcPainter(progress: _progressAnim.value),
              ),
            ),
          ),

          // ── Falke ───────────────────────────────────────────
          Positioned(
            top: screenH * 0.14,
            child: FadeTransition(
              opacity: _falconFadeAnim,
              child: SvgPicture.asset(
                'assets/images/kestrel_splash.svg',
                width: screenW * 0.75,
                colorFilter: const ColorFilter.mode(
                  KestrelColors.gold,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),

          // ── Texte (untere Hälfte) ────────────────────────────
          Positioned(
            bottom: screenH * 0.18,
            left: 48,
            right: 48,
            child: FadeTransition(
              opacity: _textFadeAnim,
              child: Column(
                children: [
                  // Headline
                  const Text(
                    'KESTREL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: KestrelColors.goldLight,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Slogan
                  const Text(
                    'HOVER · STRIKE · RIDE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: KestrelColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Sonnen-Arc Ladebalken (Text-Label)
                  AnimatedBuilder(
                    animation: _progressAnim,
                    builder: (_, __) => Text(
                      _progressAnim.value < 0.99
                          ? 'VERBINDE MIT SERVER ...'
                          : 'BEREIT',
                      style: const TextStyle(
                        color: KestrelColors.textDimmed,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sun Arc Painter ───────────────────────────────────────────
// Zeichnet einen Kreisbogen der sich von 0% → 100% füllt.
// Startpunkt: unten links (210°), Endpunkt: unten rechts (330°)
// → oberer Halbkreis erscheint wie eine aufgehende Sonne.

class _SunArcPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0

  _SunArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Hintergrund-Arc (Track)
    final trackPaint = Paint()
      ..color = const Color(0xFF1E3347)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Aktiver Arc (Gold)
    final arcPaint = Paint()
      ..color = KestrelColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Leuchtpunkt am Ende des Arcs
    final glowPaint = Paint()
      ..color = KestrelColors.gold.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Arc geht von 210° bis 330° (oben = aufgehende Sonne)
    // In Flutter: 0° = rechts, im Uhrzeigersinn
    // Wir wollen: Start unten-links (210°), Ende unten-rechts (330°)
    // = 240° Gesamtbogen
    const startAngle = 150.0 * math.pi / 180.0; // 150° in Radiant
    const sweepTotal = 240.0 * math.pi / 180.0; // 240° Gesamtbogen

    // Track (voller Bogen, gedimmt)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    if (progress > 0) {
      // Aktiver Bogen
      final sweepActive = sweepTotal * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepActive,
        false,
        arcPaint,
      );

      // Leuchtpunkt am Ende
      final endAngle = startAngle + sweepActive;
      final dotX = center.dx + radius * math.cos(endAngle);
      final dotY = center.dy + radius * math.sin(endAngle);
      canvas.drawCircle(Offset(dotX, dotY), 4.0, arcPaint);
      canvas.drawCircle(Offset(dotX, dotY), 7.0, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_SunArcPainter old) => old.progress != progress;
}