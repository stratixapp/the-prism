import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const GoogleSignInButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: _GoogleLogo(),
        label: const Text('Continue with Google'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryDark,
          side: const BorderSide(color: AppColors.borderDark, width: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: AppColors.bgDarkCard,
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    // Simplified G logo using colored arcs
    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];
    for (int i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 1.5),
        (i * 1.5708) - 0.3,
        1.2,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
