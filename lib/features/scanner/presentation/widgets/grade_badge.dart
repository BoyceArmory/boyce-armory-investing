import 'package:flutter/material.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/theme/app_colors.dart';

/// Letter-grade pill (A+, A, B, C, WATCH).
///
/// A+ / A get a gold glow.
/// C grade renders the letter with a small "WATCH" tag underneath so users
/// know to monitor without taking the trade (added May 2026 to introduce a
/// "watchlist only" tier between B and admin-only WATCH).
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
      case SetupGrade.c:
        return AppColors.textSecondary;
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            grade.label,
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              height: 1.0,
            ),
          ),
          if (grade.isWatchTier) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              'WATCH',
              style: TextStyle(
                color: _color,
                fontSize: 7.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
