import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_header.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
                eyebrow: 'Inbox',
                title: 'Notifications',
              ),
            ),
            Expanded(
              child: EmptyState(
                icon: Icons.notifications_none,
                title: 'No notifications yet',
                message:
                    'Push alerts, scanner publishes, and recaps will appear here.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
