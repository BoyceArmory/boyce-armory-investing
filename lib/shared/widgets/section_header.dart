import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Eyebrow + title pair used at the top of dashboard sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.action,
  });

  final String title;
  final String? eyebrow;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (eyebrow != null)
                Text(
                  eyebrow!.toUpperCase(),
                  style: tt.labelSmall?.copyWith(color: AppColors.gold),
                ),
              if (eyebrow != null) const SizedBox(height: 4),
              Text(title, style: tt.titleLarge),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
