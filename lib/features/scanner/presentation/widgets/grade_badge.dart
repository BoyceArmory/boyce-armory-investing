import 'package:flutter/material.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/theme/app_colors.dart';

/// Letter-grade pill (A+, A, B, WATCH). A+ / A get a gold glow.
class GradeBadge extends StatelessWidget {
  const GradeBadge({super.key, required this.grade});
  final SetupGrade grade;

  Color get _color {
    switch (grade) {
      case SetupGrade.aPlus:
        return AppColors.gold;
      case SetupGrade.a:
        return AppColors.goldBright;
      case SetupGrade.b:
        return AppColors.info;
      case SetupGrade.watch:
        return AppColors.textTertiary;
    }
  }

  bool get _premium =>
      grade == SetupGrade.aPlus || grade == SetupGrade.a;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        border: Border.all(color: _color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: _premium
            ? <BoxShadow>[
                BoxShadow(
                  color: _color.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: -3,
                ),
              ]
            : null,
      ),
      child: Text(
        grade.label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
