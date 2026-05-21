import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/buttons/ghost_button.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/premium_card.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../widgets/avatar_uploader.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser?> userAsync = ref.watch(appUserProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: userAsync.when(
        loading: () => const SafeArea(child: LoadingIndicator()),
        error: (Object e, _) => SafeArea(
          child: Center(
            child: Text(
              'Failed to load profile.\n$e',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
          ),
        ),
        data: (AppUser? u) {
          return ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const ScreenHeader(asset: AssetPaths.headerProfile),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: <Widget>[
                    BrandLogo.mark(size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: SectionHeader(
                        eyebrow: 'Account',
                        title: 'Profile',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    FadeSlideIn(
                      child: PremiumCard(
                        child: Row(
                          children: <Widget>[
                            AvatarUploader(
                              photoUrl: u?.photoUrl,
                              initials: _initials(u),
                              onUploaded: () =>
                                  ref.invalidate(appUserProvider),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    u?.displayName ?? 'Boyce Armory member',
                                    style: context.text.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    u?.email ?? '',
                                    style: context.text.bodySmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      (u?.isAdmin ?? false)
                                          ? 'ADMIN'
                                          : 'MEMBER',
                                      style: const TextStyle(
                                        color: AppColors.gold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: PremiumCard(
                        child: Column(
                          children: <Widget>[
                            _Row(
                              label: 'Active & Closed Trades',
                              onTap: () => context.go(RoutePaths.trades),
                            ),
                            const Divider(height: 24),
                            _Row(
                              label: 'Performance',
                              onTap: () => context.go(RoutePaths.performance),
                            ),
                            const Divider(height: 24),
                            _Row(
                              label: 'Lessons',
                              onTap: () => context.go(RoutePaths.lessons),
                            ),
                            const Divider(height: 24),
                            _Row(
                              label: 'Notifications',
                              onTap: () =>
                                  context.go(RoutePaths.notifications),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 140),
                      child: GhostButton(
                        label: 'Sign out',
                        icon: Icons.logout,
                        fullWidth: true,
                        onPressed: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .signOut();
                          if (context.mounted) {
                            context.go(RoutePaths.signIn);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  String _initials(AppUser? u) {
    final String name = (u?.displayName ?? u?.email ?? 'BA').trim();
    if (name.isEmpty) return 'BA';
    final List<String> parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
