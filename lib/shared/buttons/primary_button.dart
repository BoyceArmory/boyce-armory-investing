import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

/// Brand CTA button with gold gradient + soft glow.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    final Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (loading) ...<Widget>[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.obsidian),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: AppColors.obsidian),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: const TextStyle(
            color: AppColors.obsidian,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 50,
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            gradient: AppGradients.gold,
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x33CFAE57),
                      blurRadius: 18,
                      spreadRadius: -4,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}
