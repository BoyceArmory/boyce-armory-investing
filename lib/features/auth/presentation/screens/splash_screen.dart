import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_background.dart';
import '../../../../shared/widgets/brand_logo.dart';

/// Cold-boot splash. Shown while we wait for auth state to resolve.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const BrandLogo.full(size: 140),
                const SizedBox(height: 28),
                Text(
                  AppConstants.appName.toUpperCase(),
                  style: AppTypography.buildTextTheme()
                      .headlineSmall
                      ?.copyWith(letterSpacing: 6, color: AppColors.gold),
                ),
                const SizedBox(height: 6),
                const Text(
                  AppConstants.appTagline,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 18),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
