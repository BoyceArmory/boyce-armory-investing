import 'package:flutter/material.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/theme/app_colors.dart';

/// Small pill showing CALL/PUT with a colored dot + glow.
class DirectionIndicator extends StatelessWidget {
  const DirectionIndicator({super.key, required this.direction, this.dense = false});

  final SetupDirection direction;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final bool bull = direction.isBull;
    final Color color = bull ? AppColors.bullish : AppColors.bearish;
    final String label = bull ? 'CALL' : 'PUT';
    final IconData icon = bull ? Icons.trending_up : Icons.trending_down;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: dense ? 12 : 14),
          SizedBox(width: dense ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
