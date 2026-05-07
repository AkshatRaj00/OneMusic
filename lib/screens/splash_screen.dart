import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Design tokens (same as home/player) ──────────────
  static const _bg      = Color(0xFF141414);
  static const _surface = Color(0xFF1E1E1E);
  static const _accent  = Color(0xFFFF6B35);
  static const _textPrimary   = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF888888);

  // ── Controllers ───────────────────────────────────────
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _tagCtrl;
  late AnimationController _glowCtrl;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotate;

  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  late Animation<double> _tagFade;
  late Animation<Offset> _tagSlide;

  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: _bg,
    ));

    // Logo animation
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)));
    _logoScale = Tween<double>(begin: 0.6, end: 1).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));
    _logoRotate = Tween<double>(begin: -0.08, end: 0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));

    // Title animation (delayed)
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _textFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // Tagline animation (more delayed)
    _tagCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _tagFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut));
    _tagSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOutCubic));

    // Glow pulse
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Stagger sequence
    _logoCtrl.forward();
    Future.delayed(const Duration(milliseconds: 500),
        () { if (mounted) _textCtrl.forward(); });
    Future.delayed(const Duration(milliseconds: 750),
        () { if (mounted) _tagCtrl.forward(); });

    // Navigate to home
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
            child: child,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _tagCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Background glow ──────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => CustomPaint(
                painter: _GlowPainter(
                    opacity: _glowAnim.value, color: _accent),
              ),
            ),
          ),

          // ── Center content ───────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo icon
                AnimatedBuilder(
                  animation: _logoCtrl,
                  builder: (_, __) => FadeTransition(
                    opacity: _logoFade,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Transform.rotate(
                        angle: _logoRotate.value,
                        child: _LogoWidget(accent: _accent, surface: _surface),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // App name
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'One',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                            ),
                          ),
                          TextSpan(
                            text: 'Music',
                            style: TextStyle(
                              color: _accent,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Tagline
                FadeTransition(
                  opacity: _tagFade,
                  child: SlideTransition(
                    position: _tagSlide,
                    child: const Text(
                      'Music. Free. Forever.',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom branding ──────────────────────────
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: FadeTransition(
              opacity: _tagFade,
              child: const Column(
                children: [
                  Text(
                    'by',
                    style: TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ONEPERSON AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF444444),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.5,
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

// ══════════════════════════════════════════════════════════
//  Logo Widget
// ══════════════════════════════════════════════════════════
class _LogoWidget extends StatelessWidget {
  final Color accent;
  final Color surface;
  const _LogoWidget({required this.accent, required this.surface});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.25),
            blurRadius: 40,
            spreadRadius: 4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner glow circle
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
          ),
          // Icon
          Icon(Icons.graphic_eq_rounded, color: accent, size: 44),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Background Glow Painter
// ══════════════════════════════════════════════════════════
class _GlowPainter extends CustomPainter {
  final double opacity;
  final Color color;
  const _GlowPainter({required this.opacity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.7,
        colors: [
          color.withOpacity(opacity * 0.15),
          color.withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.opacity != opacity;
}