import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _spectrumController;

  @override
  void initState() {
    super.initState();
    _spectrumController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    _navigate();
  }

  @override
  void dispose() {
    _spectrumController.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    // Wait for animation + auth check
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool(AppConstants.keyOnboardingDone) ?? false;
    final authUser = ref.read(authStateProvider).valueOrNull;

    if (!mounted) return;

    if (authUser != null) {
      context.go(AppRoutes.home);
    } else if (!onboardingDone) {
      context.go(AppRoutes.onboarding);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Prism Triangle ────────────────────────────────────────
            _PrismTriangle(controller: _spectrumController)
                .animate()
                .scale(
                  duration: 800.ms,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.3, 0.3),
                  end: const Offset(1.0, 1.0),
                ),

            const SizedBox(height: 32),

            // ── App Name ──────────────────────────────────────────────
            Text(
              'THE PRISM',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimaryDark,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w700,
                  ),
            )
                .animate(delay: 400.ms)
                .fadeIn(duration: 600.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 8),

            // ── Tagline ───────────────────────────────────────────────
            Text(
              AppConstants.appTagline,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiaryDark,
                    letterSpacing: 0.5,
                  ),
            )
                .animate(delay: 600.ms)
                .fadeIn(duration: 600.ms),

            const SizedBox(height: 8),

            // ── Stratix Badge ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppColors.prismPurple.withOpacity(0.4), width: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'by ${AppConstants.brandName}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.prismPurple,
                      letterSpacing: 1,
                    ),
              ),
            )
                .animate(delay: 800.ms)
                .fadeIn(duration: 600.ms),

            const SizedBox(height: 64),

            // ── Loading dots ──────────────────────────────────────────
            _LoadingDots()
                .animate(delay: 1000.ms)
                .fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}

// ── Animated Prism Triangle ───────────────────────────────────────────────────
class _PrismTriangle extends StatelessWidget {
  final AnimationController controller;

  const _PrismTriangle({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _PrismPainter(progress: controller.value),
          ),
        );
      },
    );
  }
}

class _PrismPainter extends CustomPainter {
  final double progress;
  _PrismPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Triangle path
    final path = Path();
    path.moveTo(cx, 8);
    path.lineTo(size.width - 8, size.height - 8);
    path.lineTo(8, size.height - 8);
    path.close();

    // Glow behind triangle
    final glowPaint = Paint()
      ..color = AppColors.prismPurple.withOpacity(0.15 * progress)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawPath(path, glowPaint);

    // Triangle fill (dark)
    final fillPaint = Paint()
      ..color = AppColors.bgDarkCard
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Triangle border — purple
    final borderPaint = Paint()
      ..color = AppColors.prismPurple.withOpacity(0.6 + 0.4 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);

    // Spectrum rays radiating from right vertex
    final rayColors = AppColors.spectrumGradient;
    final startX = size.width - 8.0;
    final startY = size.height - 8.0;

    for (int i = 0; i < rayColors.length; i++) {
      final t = i / (rayColors.length - 1);
      final angle = (0.3 + t * 0.7) * 3.14159;
      final length = 28.0 + t * 20;
      final opacity = progress * (0.4 + t * 0.4);

      final paint = Paint()
        ..color = rayColors[i].withOpacity(opacity)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX + length * (-1),
            startY + length * (-0.8 + t * 1.4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PrismPainter old) => old.progress != progress;
}

// ── Loading dots ──────────────────────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = ((_c.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.prismPurple.withOpacity(opacity),
              ),
            );
          }),
        );
      },
    );
  }
}
