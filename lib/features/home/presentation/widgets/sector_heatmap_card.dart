import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/home_overview_model.dart';
import '../providers/home_providers.dart';

class SectorHeatmapCard extends ConsumerWidget {
  const SectorHeatmapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      homeOverviewStreamProvider,
    );

    return async.maybeWhen(
      data: (o) {
        if (o.sectors.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),

            image: const DecorationImage(
              image: AssetImage(
                'assets/backgrounds/heat_map.png',
              ),

              fit: BoxFit.fitWidth,

              alignment:
                  Alignment.topCenter,
            ),
          ),

          // raised another half inch
          padding: const EdgeInsets.fromLTRB(
            38,
  145,
  8,
  24,
),

          child: LayoutBuilder(
            builder: (context, c) {
              final cols =
                  c.maxWidth > 380 ? 4 : 3;

              return GridView.count(
                shrinkWrap: true,

                physics:
                    const NeverScrollableScrollPhysics(),

                crossAxisCount: cols,

                crossAxisSpacing: 10,
                mainAxisSpacing: 10,

                childAspectRatio: 0.92,

                children: [
                  for (final s in o.sectors)
                    _SectorTile(
                      quote: s,
                    ),
                ],
              );
            },
          ),
        );
      },

      orElse: () =>
          const SizedBox.shrink(),
    );
  }
}

class _SectorTile extends StatelessWidget {
  const _SectorTile({
    required this.quote,
  });

  final MiniQuote quote;

  @override
  Widget build(BuildContext context) {
    final pct = quote.changePct;

    final numberColor =
        pct >= 0
            ? AppColors.bullish
            : AppColors.bearish;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: 0.00,
        ),

        borderRadius:
            BorderRadius.circular(14),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.35,
            ),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      padding: const EdgeInsets.fromLTRB(
        10,
        10,
        10,
        10,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

        children: [
          Text(
            quote.symbol,

            maxLines: 1,

            overflow:
                TextOverflow.ellipsis,

            style: const TextStyle(
              color:
                  AppColors.textPrimary,

              fontSize: 18,

              fontWeight:
                  FontWeight.w900,

              letterSpacing: 0.3,

              height: 1,
            ),
          ),

          Text(
            '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',

            style: TextStyle(
              color: numberColor,

              fontSize: 18,

              fontWeight:
                  FontWeight.w900,

              height: 1,
            ),
          ),

          if (quote.name != null)
            Text(
              quote.name!
                  .toUpperCase(),

              maxLines: 2,

              overflow:
                  TextOverflow.ellipsis,

              style: const TextStyle(
                color: Colors.white,

                fontSize: 11.5,

                fontWeight:
                    FontWeight.w900,

                height: 1.1,

                letterSpacing: 0.3,
              ),
            ),
        ],
      ),
    );
  }
}