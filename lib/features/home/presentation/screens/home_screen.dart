import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/scanner_alert_model.dart';
import '../../../../core/models/trade_alert_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/asset_paths.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../alerts/presentation/providers/alerts_providers.dart';
import '../../../alerts/presentation/widgets/hot_trade_card.dart';
import '../../../scanner/presentation/providers/scanner_providers.dart';
import '../../../scanner/presentation/widgets/scanner_alert_card.dart';
import '../../../scanner/presentation/widgets/scanner_card_skeleton.dart';
import '../widgets/market_pulse_card.dart';
import '../widgets/quick_action_grid.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser?> userAsync = ref.watch(appUserProvider);
    final AsyncValue<List<TradeAlert>> hotAsync = ref.watch(hotAlertsProvider);
    final AsyncValue<List<ScannerAlert>> scannerAsync =
        ref.watch(publicScannerAlertsProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.graphite,
        onRefresh: () async {
          ref.invalidate(hotAlertsProvider);
          ref.invalidate(publicScannerAlertsProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const ScreenHeader(asset: AssetPaths.headerHome),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: _HomeBody(userAsync: userAsync, hotAsync: hotAsync, scannerAsync: scannerAsync),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({
    required this.userAsync,
    required this.hotAsync,
    required this.scannerAsync,
  });

  final AsyncValue<AppUser?> userAsync;
  final AsyncValue<List<TradeAlert>> hotAsync;
  final AsyncValue<List<ScannerAlert>> scannerAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
            FadeSlideIn(
              child: MarketPulseCard(
                displayName: userAsync.asData?.value?.displayName,
              ),
            ),
            const SizedBox(height: 18),
            const FadeSlideIn(
              delay: Duration(milliseconds: 80),
              child: QuickActionGrid(),
            ),
            const SizedBox(height: 22),

            // --- Hot trades preview ---
            FadeSlideIn(
              delay: const Duration(milliseconds: 130),
              child: SectionHeader(
                eyebrow: 'Curated',
                title: 'Hot Trades',
                action: TextButton(
                  onPressed: () => context.go(RoutePaths.hotTrades),
                  child: const Text('View all'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            hotAsync.when(
              loading: () => const ScannerCardSkeleton(),
              error: (Object e, _) => ErrorState(
                message: 'Could not load hot trades.',
                details: e.toString(),
                onRetry: () => ref.invalidate(hotAlertsProvider),
              ),
              data: (List<TradeAlert> alerts) {
                if (alerts.isEmpty) {
                  return const EmptyState(
                    icon: Icons.local_fire_department_outlined,
                    title: 'No hot trades right now',
                    message: 'Check back soon - the desk publishes here first.',
                  );
                }
                final TradeAlert featured = alerts.first;
                return FadeSlideIn(
                  delay: const Duration(milliseconds: 180),
                  child: HotTradeCard(
                    alert: featured,
                    onOpenDetail: () =>
                        context.go(RoutePaths.alertDetailFor(featured.id)),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // --- Scanner preview ---
            FadeSlideIn(
              delay: const Duration(milliseconds: 220),
              child: SectionHeader(
                eyebrow: 'Live',
                title: 'From the Scanner',
                action: TextButton(
                  onPressed: () => context.go(RoutePaths.scanner),
                  child: const Text('Open'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            scannerAsync.when(
              loading: () => const Column(
                children: <Widget>[
                  ScannerCardSkeleton(),
                  SizedBox(height: 12),
                  ScannerCardSkeleton(),
                ],
              ),
              error: (Object e, _) => ErrorState(
                message: 'Could not load scanner alerts.',
                details: e.toString(),
                onRetry: () => ref.invalidate(publicScannerAlertsProvider),
              ),
              data: (List<ScannerAlert> list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.radar,
                    title: 'Scanner is quiet',
                    message:
                        'Setups will stream in as soon as they\'re detected.',
                  );
                }
                final List<ScannerAlert> top = list.take(3).toList();
                return Column(
                  children: <Widget>[
                    for (int i = 0; i < top.length; i++) ...<Widget>[
                      FadeSlideIn(
                        delay: Duration(milliseconds: 260 + 50 * i),
                        child: ScannerAlertCard(
                          alert: top[i],
                          onOpenDetail: () => context.go(
                            RoutePaths.scannerDetailFor(top[i].id),
                          ),
                        ),
                      ),
                      if (i < top.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
      ],
    );
  }
}
