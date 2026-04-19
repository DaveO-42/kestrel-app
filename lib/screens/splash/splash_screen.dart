import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';
import 'dart:ui' as ui;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  String _appVersion     = '';
  String _backendVersion = '';
  String _statusText     = 'SYSTEM WIRD INITIALISIERT ...';

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
      duration: const Duration(milliseconds: 500),
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
    final results = await Future.wait([
      PackageInfo.fromPlatform(),
      SharedPreferences.getInstance(),
    ]);
    final info  = results[0] as PackageInfo;
    final prefs = results[1] as SharedPreferences;

    if (!mounted) return;
    setState(() {
      _appVersion     = info.version;
      _backendVersion = prefs.getString('version_backend') ?? '–';
    });

    _falconFadeController.forward();
    await Future.delayed(const Duration(milliseconds: 400));

    _textFadeController.forward();

    setState(() => _statusText = 'VERBINDE MIT SERVER ...');
    await _setProgress(0.35, ms: 600);

    if (mounted) setState(() => _statusText = 'POSITIONEN WERDEN GELADEN ...');
    await _setProgress(0.70, ms: 500);

    if (mounted) setState(() => _statusText = 'PIPELINE WIRD GEPRÜFT ...');
    await _setProgress(1.0, ms: 400);

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _statusText = 'BEREIT');

    await Future.delayed(const Duration(milliseconds: 200));

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



    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      body: Stack(
        alignment: Alignment.center,
        children: [

          // ── Hintergrund: Verlauf + radialer Glow ─────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _BackgroundPainter(),
            ),
          ),


          // ── Falke ───────────────────────────────────────────
          Positioned(
            top: screenH * 0.15,
            child: FadeTransition(
              opacity: _falconFadeAnim,
              child: Image.asset('assets/images/polygon_splash.png', width: screenW * 0.75)
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
                      color: KestrelColors.gold,
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

                  const SizedBox(height: 32),
                  SizedBox(
                    width: 200,
                    height: 12,
                    child: AnimatedBuilder(
                      animation: _progressAnim,
                      builder: (_, __) => CustomPaint(
                        painter: _ProgressBarPainter(progress: _progressAnim.value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _progressAnim,
                    builder: (_, __) => Text(
                      _statusText,
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
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Text(
              _appVersion.isNotEmpty && _backendVersion.isNotEmpty
                  ? 'app $_appVersion  ·  kestrel $_backendVersion'
                  : '',
              style: const TextStyle(
                color: KestrelColors.textHint,
                fontSize: 10,
                letterSpacing: 1.2,
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

class _ProgressBarPainter extends CustomPainter {
  final double progress;

  _ProgressBarPainter({required this.progress});

  static const double _height = 12.0;
  static const double _radius = 6.0;
  static const double _padding = 2.0;
  static const double _borderWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = KestrelColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = _borderWidth;

    final fillPaint = Paint()
      ..color = KestrelColors.gold
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = KestrelColors.goldLight.withOpacity(0.35)
      ..style = PaintingStyle.fill;

    final glowPaint2 = Paint()
      ..color = KestrelColors.goldLight.withOpacity(0.75)
      ..style = PaintingStyle.fill;

    // Rahmen (Pill)
    final borderRect = RRect.fromLTRBR(
      0, 0, size.width, _height,
      const Radius.circular(_radius),
    );
    canvas.drawRRect(borderRect, borderPaint);

    // Innere Füllung
    if (progress > 0) {
      final innerW = (size.width - _padding * 2) * progress;
      final fillRect = RRect.fromLTRBR(
        _padding, _padding,
        _padding + innerW, _height - _padding,
        const Radius.circular(_radius - _padding),
      );
      canvas.drawRRect(fillRect, fillPaint);

      // Leuchtpunkt an der Spitze
      final dotX = _padding + innerW;
      final dotY = _height / 2;
      canvas.drawCircle(Offset(dotX, dotY), 7, glowPaint);
      canvas.drawCircle(Offset(dotX, dotY), 4, glowPaint2);
    }
  }

  @override
  bool shouldRepaint(_ProgressBarPainter old) => old.progress != progress;
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Vertikaler Verlauf
    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [
          const Color(0xFF131F2E), // oben — etwas heller
          const Color(0xFF0F1822), // Mitte — screenBg
          const Color(0xFF0A1018), // unten — etwas dunkler
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gradientPaint);

    // Radialer Glow hinter Falken (~40% von oben)
    final glowCenter = Offset(size.width / 2, size.height * 0.40);
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        glowCenter,
        size.width * 0.55,
        [
          const Color(0xFFC9A84C).withOpacity(0.10),
          const Color(0xFF0F1822).withOpacity(0.0),
        ],
      );
    canvas.drawCircle(glowCenter, size.width * 0.55, glowPaint);
    _drawCandlesticks(canvas, size);
  }

  void _drawCandlesticks(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9A84C).withOpacity(0.09)
      ..style = PaintingStyle.fill;
    final wickPaint = Paint()
      ..color = const Color(0xFFC9A84C).withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final candles = [
      (size.width * 0.08, size.height * 0.72, 28.0, size.height * 0.68, size.height * 0.82),
      (size.width * 0.18, size.height * 0.68, 20.0, size.height * 0.64, size.height * 0.80),
      (size.width * 0.28, size.height * 0.74, 32.0, size.height * 0.70, size.height * 0.86),
      (size.width * 0.38, size.height * 0.65, 18.0, size.height * 0.62, size.height * 0.78),
      (size.width * 0.62, size.height * 0.67, 24.0, size.height * 0.63, size.height * 0.80),
      (size.width * 0.72, size.height * 0.70, 30.0, size.height * 0.66, size.height * 0.84),
      (size.width * 0.82, size.height * 0.66, 22.0, size.height * 0.62, size.height * 0.79),
      (size.width * 0.92, size.height * 0.73, 26.0, size.height * 0.69, size.height * 0.83),
    ];

    const candleW = 10.0;

    for (final c in candles) {
      final x = c.$1;
      canvas.drawLine(Offset(x, c.$4), Offset(x, c.$5), wickPaint);
      canvas.drawRect(Rect.fromLTWH(x - candleW / 2, c.$2, candleW, c.$3), paint);
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => false;
}