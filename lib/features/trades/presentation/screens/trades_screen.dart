import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_header.dart';

/// Placeholder screen for the Trades tab. Will host active / closed trades
/// once the backend feed is exposed to the app.
class TradesScreen extends StatelessWidget {
  const TradesScreen({super.key});

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
                eyebrow: 'Tracker',
                title: 'Active & Closed Trades',
              ),
            ),
            Expanded(
              child: EmptyState(
                icon: Icons.trending_up,
                title: 'Trade tracking coming soon',
                message:
                    'Your active positions and closed history will live here once the backend feed is wired up.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
