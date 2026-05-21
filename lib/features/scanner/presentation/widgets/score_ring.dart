import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Circular score indicator (0-100) used on scanner cards.
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 52});

  final int score;
  final double size;

  Color get _ringColor {
    if (score >= 90) return AppColors.gold;
    if (score >= 80) return AppColors.goldBright;
    if (score >= 70) return AppColors.info;
    return AppColors.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              progress: (score.clamp(0, 100)) / 100,
              ringColor: _ringColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$score',
                style: AppTypography.mono(
                  size: size * 0.32,
                  weight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'SCORE',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: size * 0.16,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.ringColor});
  final double progress;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 3;
    final Paint bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = AppColors.steel;
    final Paint fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: <Color>[ringColor.withValues(alpha: 0.4), ringColor],
        stops: const <double>[0.0, 1.0],
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, bg);
    final double sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}
