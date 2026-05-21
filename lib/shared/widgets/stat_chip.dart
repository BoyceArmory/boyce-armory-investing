import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Compact pill showing a label + monospace numeric value. Used inside cards
/// for entry/target/stop, etc.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.dense = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 6 : 9,
      ),
      decoration: BoxDecoration(
        color: AppColors.carbon,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.steel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: tt.labelSmall?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTypography.mono(
              size: dense ? 13 : 14,
              weight: FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
