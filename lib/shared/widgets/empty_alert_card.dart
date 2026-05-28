import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'card_background.dart';

/// Empty-state card that mirrors the layout of a real scanner / hot trade
/// card so the screen still feels intentional when no alerts are firing.
///
/// Layout matches `ScannerAlertCard`:
///   - Full-bleed artwork (defaults to the bull_call_bg)
///   - All copy right-aligned on the right half of the card
///   - Eyebrow + title + helper message
///
/// Why this exists: Apple's App Store review (submission 67feecab,
/// May 27 2026, iPad Air 11" M3) flagged the Scanner and Hot Trades pages
/// under Guideline 2.1(a) because content "did not load." The reviewer
/// likely tested outside US market hours when the scanner has no live
/// signals to publish. Showing a dummy card with an obvious explanation
/// avoids the appearance of a broken or perpetually-loading view.
class EmptyAlertCard extends StatelessWidget {
  const EmptyAlertCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.message,
    this.art = CardArt.bullCall,
    this.icon = Icons.radar_outlined,
  });

  /// Short label above the title — e.g. "MARKETS QUIET".
  final String eyebrow;

  /// Bold one-line title — e.g. "No active setups".
  final String title;

  /// 1–2 sentence explanation of WHY this is empty + what the user should
  /// expect (market hours, refresh cadence, etc.).
  final String message;

  /// Background art. Defaults to bull_call_bg to keep the empty card visually
  /// consistent with the rest of the alert surface, but callers can override.
  final CardArt art;

  /// Glyph rendered above the eyebrow on the right side of the card.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CardBackground(
      art: art,
      accentColor: AppColors.steel,
      borderRadius: 22,
      minHeight: 240,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: 0.62,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _ShadowedIcon(icon: icon),
              const SizedBox(height: 10),
              _ShadowedText(
                eyebrow,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              _ShadowedText(
                title,
                textAlign: TextAlign.right,
                style: AppTypography.mono(
                  size: 20,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              _ShadowedText(
                message,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFFE7E9EE),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drop-shadow icon so the glyph stays legible on top of the artwork.
class _ShadowedIcon extends StatelessWidget {
  const _ShadowedIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Icon(icon, size: 32, color: const Color(0xAA000000)),
        Positioned(
          top: -1,
          left: -1,
          child: Icon(icon, size: 32, color: AppColors.gold),
        ),
      ],
    );
  }
}

/// Local text helper with a soft drop shadow so labels stay legible on the
/// full-bleed artwork. Kept private to this file (same pattern as the real
/// alert cards).
class _ShadowedText extends StatelessWidget {
  const _ShadowedText(this.text, {required this.style, this.textAlign});
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: style.copyWith(
        shadows: const <Shadow>[
          Shadow(
            color: Color(0xAA000000),
            offset: Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
