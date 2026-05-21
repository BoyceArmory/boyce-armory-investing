import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_header.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.obsidian,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SectionHeader(
                eyebrow: 'Track record',
                title: 'Performance',
              ),
            ),
            Expanded(
              child: EmptyState(
                icon: Icons.show_chart,
                title: 'Performance dashboard coming soon',
                message:
                    'Win rate, average gain/loss, best/worst trades, and monthly stats will land here.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
