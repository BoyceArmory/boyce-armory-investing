import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/lesson_models.dart';

/// Maps a LearnTrack to its accent color + icon. Centralized so list, section,
/// and detail screens stay visually consistent.
class TrackStyle {
  const TrackStyle({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  static TrackStyle forTrack(LearnTrack track) {
    switch (track) {
      case LearnTrack.foundations:
        return const TrackStyle(
          color: AppColors.info,
          icon: Icons.auto_stories_outlined,
        );
      case LearnTrack.options:
        return const TrackStyle(
          color: AppColors.gold,
          icon: Icons.candlestick_chart_outlined,
        );
      case LearnTrack.technicals:
        return const TrackStyle(
          color: AppColors.bullish,
          icon: Icons.show_chart,
        );
      case LearnTrack.risk:
        return const TrackStyle(
          color: AppColors.bearish,
          icon: Icons.shield_outlined,
        );
      case LearnTrack.execution:
        return const TrackStyle(
          color: AppColors.goldBright,
          icon: Icons.play_circle_outline,
        );
    }
  }
}
