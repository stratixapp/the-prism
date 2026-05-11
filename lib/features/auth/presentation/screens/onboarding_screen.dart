import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      title: 'One file.\nTen expert minds.',
      subtitle:
          'Upload any PDF, ZIP, APK, report, or document. The Prism instantly activates 10 AI specialists to analyze it from every angle simultaneously.',
      illustration: _Illustration.prism,
      accentColor: AppColors.prismPurple,
    ),
    _OnboardingPage(
      title: 'The full spectrum\nof intelligence.',
      subtitle:
          'Research analyst. Gap finder. Future strategist. Risk evaluator. Pattern reader. Innovation scout. All running in parallel — in seconds.',
      illustration: _Illustration.agents,
      accentColor: AppColors.agentMarcus,
    ),
    _OnboardingPage(
      title: 'One verdict.\nZero noise.',
      subtitle:
          'Chen, the master synthesizer, reads all 10 agents and delivers the single most important insight, gap, and opportunity. Clear. Bold. Decisive.',
      illustration: _Illustration.verdict,
      accentColor: AppColors.agentZara,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyOnboardingDone, true);
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textTertiaryDark,
                      ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) =>
                    _OnboardingPageWidget(page: _pages[i]),
              ),
            ),

            // Indicators + Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? _pages[_currentPage].accentColor
                              : AppColors.borderDark,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages[_currentPage].accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _currentPage < _pages.length - 1
                            ? 'Next'
                            : 'Get Started',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page Data ────────────────────────────────────────────────────────────────
enum _Illustration { prism, agents, verdict }

class _OnboardingPage {
  final String title;
  final String subtitle;
  final _Illustration illustration;
  final Color accentColor;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.accentColor,
  });
}

// ── Page Widget ───────────────────────────────────────────────────────────────
class _OnboardingPageWidget extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageWidget({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          _buildIllustration(page.illustration, page.accentColor)
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut),

          const SizedBox(height: 48),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimaryDark,
                  height: 1.2,
                ),
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 200.ms)
              .slideY(begin: 0.1, end: 0),

          const SizedBox(height: 20),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondaryDark,
                  height: 1.6,
                ),
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 350.ms),
        ],
      ),
    );
  }

  Widget _buildIllustration(_Illustration type, Color accent) {
    switch (type) {
      case _Illustration.prism:
        return SizedBox(
          width: 140,
          height: 140,
          child: CustomPaint(painter: _PrismIllustration(accent: accent)),
        );
      case _Illustration.agents:
        return _AgentsIllustration(accent: accent);
      case _Illustration.verdict:
        return _VerdictIllustration(accent: accent);
    }
  }
}

// ── Illustrations ─────────────────────────────────────────────────────────────
class _PrismIllustration extends CustomPainter {
  final Color accent;
  const _PrismIllustration({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // Big triangle
    final path = Path()
      ..moveTo(cx, 10)
      ..lineTo(size.width - 10, size.height - 10)
      ..lineTo(10, size.height - 10)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withOpacity(0.08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Spectrum rays
    final colors = AppColors.spectrumGradient;
    for (int i = 0; i < colors.length; i++) {
      final t = i / (colors.length - 1);
      final paint = Paint()
        ..color = colors[i].withOpacity(0.7)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width - 10, size.height - 10),
        Offset(size.width - 10 + 30 * (-1),
            size.height - 10 + 24 * (-1 + t * 1.6)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _AgentsIllustration extends StatelessWidget {
  final Color accent;
  const _AgentsIllustration({required this.accent});

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.agentPriya, AppColors.agentMarcus, AppColors.agentZara,
      AppColors.agentLeon, AppColors.agentAiko, AppColors.agentSofia,
      AppColors.agentRavi, AppColors.agentVex, AppColors.agentMorgan,
      AppColors.agentChen,
    ];
    return SizedBox(
      width: 140,
      height: 140,
      child: GridView.count(
        crossAxisCount: 5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: colors
            .map((c) => Container(
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.withOpacity(0.5), width: 1),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _VerdictIllustration extends StatelessWidget {
  final Color accent;
  const _VerdictIllustration({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withOpacity(0.1),
        border: Border.all(color: accent.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.2),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(Icons.auto_awesome, color: accent, size: 48),
    );
  }
}
