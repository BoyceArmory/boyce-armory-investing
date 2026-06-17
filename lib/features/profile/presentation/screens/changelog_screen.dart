import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Static in-app changelog. Mirrors the major slices shipped per version
/// so users discovering features later can browse what's actually new
/// vs what's been around. Updated by hand on each version bump — kept
/// terse + customer-facing (no internal jargon like "slice N").
class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  static const List<_Release> _releases = <_Release>[
    _Release(
      version: '2.4.0',
      tagline: 'Notifications you actually control + admin drilldowns',
      bullets: <String>[
        'Chat: gold unread badges per room + cross-tab rollup on the Chat icon.',
        'Chat: mute any room with the bell in the AppBar — silences badge AND backend pushes.',
        'Chat: search any room\'s recent messages by text or sender.',
        'Chat: "Mark all read" sweep clears every badge in one tap.',
        'Snooze: silence ALL notifications for 1h / 8h / Until 8am / custom window.',
        'Snooze: persistent gold indicator on Home, Hot Trades, and Scanner so you never forget you\'re muted.',
        'Settings: "Send test push to me" diagnostic that respects your settings.',
        'Settings: "Reset notification settings" destructive action that wipes prefs + mutes back to defaults.',
        'Settings: ACCOUNT section with member-since, last sign-in, and Support ID.',
        'Settings: HELP section with one-tap deep links to lessons + bug report mailer.',
        'Profile: at-a-glance notifications status row (ON / OFF / Snoozed until X).',
        'Home: push-permission banner if iOS has blocked notifications while your app pref is ON.',
        'Empty states: Hot Trades and Track Record both feel intentional rather than blank.',
        'Admin: tappable drilldowns on Backtest, Learning, Errors, Trades, Detectors — every row → full report sheet with copy-raw-JSON.',
      ],
    ),
    _Release(
      version: '2.3.0',
      tagline: 'Chat features groundwork',
      bullets: <String>[
        'Chat: @mentions with autocomplete typeahead.',
        'Chat: @everyone broadcasts for admins; per-user phone pings.',
        'Chat: announcements post to general chat AND fire push.',
        'Backend: per-room mute respected at fan-out so muted users genuinely don\'t buzz.',
      ],
    ),
    _Release(
      version: '2.2.0',
      tagline: 'Position sizing + shadow track record',
      bullets: <String>[
        'Position sizing chip on every alert card (qty + total cost + % risk).',
        'Shadow performance screen — every A+ scanner alert is auto-tracked end-to-end so you can audit edge.',
        'Premarket push gets its own channel (so muting premarket no longer silences scanner alerts).',
        'Lessons batch: trade-card anatomy, IV rank vs percentile, gamma exposure, three trade plans.',
      ],
    ),
    _Release(
      version: '2.1.0',
      tagline: 'Options analytics + learning loop',
      bullets: <String>[
        'IV rank + percentile service, options flow (sweeps + ISO), max pain + P/C ratio + GEX.',
        '0DTE detection + earnings IV crush warnings on cards.',
        'Multi-leg spread suggester for big debits.',
        'Notification center: full history of every push, filterable by channel.',
        'Quiet hours + per-mode scanner toggles + scanner minimum grade gate.',
      ],
    ),
    _Release(
      version: '2.0.0',
      tagline: 'Scanner rebuild + admin dashboard',
      bullets: <String>[
        'Day / swing / LEAPS scanner pipelines.',
        'Hot Trades hand-picked promotions + ADMIN BUYS chat room with auto-push.',
        'Full admin dashboard: Status, Alerts, Users, Trades, Audit, Backtest, Learning.',
        'In-app track record page with equity curve + monthly P&L.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: AppColors.obsidian,
        title: const Text(
          "WHAT'S NEW",
          style: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.gold),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _releases.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (BuildContext c, int i) => _ReleaseCard(release: _releases[i]),
      ),
    );
  }
}

class _Release {
  const _Release({
    required this.version,
    required this.tagline,
    required this.bullets,
  });
  final String version;
  final String tagline;
  final List<String> bullets;
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release});
  final _Release release;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.steel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.gold),
                ),
                child: Text(
                  'v${release.version}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  release.tagline,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final b in release.bullets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
