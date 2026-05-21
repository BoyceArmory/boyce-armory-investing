import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Single-source loading affordance. Use everywhere instead of raw
/// CircularProgressIndicator so the brand color stays consistent.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.size = 28,
    this.label,
  });

  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          if (label != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              label!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
