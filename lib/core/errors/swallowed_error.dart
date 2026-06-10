import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Drop-in replacement for `error: (e, _) => const SizedBox.shrink()` in
/// `AsyncValue.when(...)` blocks. Same visual behavior — the widget tree
/// stays clean for the user — but the error is recorded to Crashlytics
/// as non-fatal so we can see prod degradation.
///
/// Pre-existing pattern across customer screens silently swallowed every
/// async error and the only signal was an empty space where a chart or
/// list should have been. Backends could be down for an hour and we'd
/// never know unless a user manually wrote in. This puts every swallow
/// on the dashboard with a `where` tag so we can group by screen.
///
/// Examples:
/// ```dart
/// error: (Object e, StackTrace s) =>
///     swallowError(e, s, where: 'home.market_pulse'),
/// ```
///
/// Defaults: `fatal: false` (these aren't crashes), and skipped entirely
/// in debug so hot-reload churn doesn't pollute the dashboard.
Widget swallowError(
  Object error,
  StackTrace stack, {
  String? where,
  Widget? child,
}) {
  if (!kDebugMode) {
    // Fire-and-forget. Recording errors is best-effort and we never
    // want a logging failure to take down the screen.
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: false,
        reason: where ?? 'silent_widget_error',
      );
    } catch (_) {
      // Silent. Crashlytics not initialized yet, or platform issue.
    }
  }
  return child ?? const SizedBox.shrink();
}
