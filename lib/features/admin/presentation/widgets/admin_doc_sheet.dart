import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Generic admin "view raw document" bottom sheet. Used to drill into
/// any Firestore-shaped Map<String, dynamic> — scanner alerts, trade
/// alerts, scan runs, audit logs, etc. Shows the doc as pretty-printed
/// JSON with a one-tap copy-all action so the admin can paste into
/// Sentry, a debugging Slack thread, or wherever else.
///
/// Why a single shared sheet rather than per-collection detail screens:
/// the schemas churn often enough that a structured viewer is constantly
/// out of date. Raw JSON is always correct.
class AdminDocSheet extends StatelessWidget {
  const AdminDocSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.doc,
  });

  final String title;
  final String subtitle;
  final Map<String, dynamic> doc;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Map<String, dynamic> doc,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.graphite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AdminDocSheet(
        title: title,
        subtitle: subtitle,
        doc: doc,
      ),
    );
  }

  String get _pretty {
    try {
      // Replacer pass: drop non-encodable values (Timestamp objects come
      // through as nested maps from the API already, so this is mostly a
      // belt-and-suspenders guard).
      return const JsonEncoder.withIndent('  ').convert(doc);
    } catch (_) {
      return doc.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pretty = _pretty;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.steel,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pretty));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Doc copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy,
                      size: 14, color: AppColors.gold),
                  label: const Text(
                    'Copy',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.steel, height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: SelectableText(
                pretty,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
