import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/kestrel_theme.dart';
import '../../main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordCtrl = TextEditingController();
  bool _obscure  = true;
  bool _loading  = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordCtrl.text.trim();
    if (password.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final ok = await AuthService().login(password);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const MainScreen(),
            transitionsBuilder: (_, anim, _, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      } else {
        setState(() { _error = 'Falsches Passwort'; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Verbindungsfehler'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: KestrelColors.screenBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SizedBox(
            height: screenH - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: KestrelColors.gold.withValues(alpha: 0.05),
                        blurRadius: 160,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: KestrelColors.gold.withValues(alpha: 0.05),
                        blurRadius: 180,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/kestrel_login.png',
                    width: screenW * 0.75,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'KESTREL',
                  style: TextStyle(
                    color: KestrelColors.gold,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8.0,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'HOVER · STRIKE · RIDE',
                  style: TextStyle(
                    color: KestrelColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 48),

                // ── Passwortfeld ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    autofocus: false,
                    onSubmitted: (_) => _submit(),
                    style: const TextStyle(
                      color: KestrelColors.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: KestrelColors.cardBg,
                      hintText: 'Passwort',
                      hintStyle: const TextStyle(
                          color: KestrelColors.textDimmed, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: KestrelColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: KestrelColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: KestrelColors.gold),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: KestrelColors.textDimmed,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                ),

                // ── Fehlermeldung ────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                        color: KestrelColors.red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 20),

                // ── Login-Button ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KestrelColors.gold,
                        disabledBackgroundColor:
                            KestrelColors.gold.withValues(alpha: 0.4),
                        foregroundColor: const Color(0xFF0F1822),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Color(0xFF0F1822),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Anmelden',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
