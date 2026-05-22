import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/home_providers.dart';

/// Premium market news widget
/// Uses custom NEWS background image.
class NewsTickerCard extends ConsumerWidget {
  const NewsTickerCard({super.key});

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final async = ref.watch(
      homeOverviewStreamProvider,
    );

    return async.maybeWhen(
      data: (o) {
        if (o.news.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          constraints: const BoxConstraints(
            minHeight: 560,
          ),

          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),

            image: const DecorationImage(
              image: AssetImage(
                'assets/backgrounds/news.png',
              ),

              // prevents image cropping
              fit: BoxFit.contain,

              alignment:
                  Alignment.topCenter,
            ),
          ),

          padding: const EdgeInsets.fromLTRB(
            20,
            145,
            20,
            20,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              for (final n in o.news.take(5))
                Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),

                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          Colors.black.withValues(
                        alpha: 0.80,
                      ),

                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),

                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black
                                  .withValues(
                            alpha: 0.35,
                          ),

                          blurRadius: 10,

                          spreadRadius: 1,

                          offset:
                              const Offset(
                            0,
                            3,
                          ),
                        ),
                      ],
                    ),

                    padding:
                        const EdgeInsets.fromLTRB(
                      14,
                      12,
                      14,
                      12,
                    ),

                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [
                        Container(
                          width: 7,
                          height: 7,

                          margin:
                              const EdgeInsets.only(
                            top: 6,
                            right: 10,
                          ),

                          decoration:
                              const BoxDecoration(
                            color:
                                AppColors.gold,

                            shape:
                                BoxShape.circle,
                          ),
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [
                              Text(
                                n.headline,

                                maxLines: 2,

                                overflow:
                                    TextOverflow
                                        .ellipsis,

                                style:
                                    const TextStyle(
                                  color:
                                      AppColors
                                          .textPrimary,

                                  fontSize: 14,

                                  fontWeight:
                                      FontWeight
                                          .w800,

                                  height: 1.3,
                                ),
                              ),

                              const SizedBox(
                                height: 6,
                              ),

                              if (n.source !=
                                  null)
                                Text(
                                  n.source!
                                      .toUpperCase(),

                                  style:
                                      const TextStyle(
                                    color: Colors
                                        .white,

                                    fontSize:
                                        11,

                                    fontWeight:
                                        FontWeight
                                            .w700,

                                    letterSpacing:
                                        0.4,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },

      orElse: () =>
          const SizedBox.shrink(),
    );
  }
}