import 'package:flutter/material.dart';

/// Wide-screen-aware content container.
///
/// On phones (< 600pt wide), behaves as a no-op — child renders edge-to-edge
/// as before. On iPad / large displays, caps content width at `maxWidth`
/// (default 700pt) and centres it horizontally so cards and lists don't
/// stretch across the full panel awkwardly.
///
/// Use it at the root of every scrolling content area. Drop-in safe: doesn't
/// add padding or alter scroll physics; just constrains horizontal extent
/// when the screen is wide.
///
/// Common usage:
///   ListView(...)         → ResponsiveContainer(child: ListView(...))
///   Column(...)           → ResponsiveContainer(child: Column(...))
///   CustomScrollView(...) → ResponsiveContainer(child: CustomScrollView(...))
///
/// Why this is the right call:
///   - iPhone untouched (no visual change on the ~93% of usage where width
///     is already correct)
///   - iPad finally stops stretching a $142.10 entry across 1366pt
///   - One file to tune the breakpoint or max width if the design changes
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 700,
    this.breakpoint = 600,
  });

  /// The widget to render inside the constraint.
  final Widget child;

  /// Maximum content width on wide screens. 700pt matches the visual rhythm
  /// of our card layouts; bump to 760-800 if cards feel cramped on iPad Pro.
  final double maxWidth;

  /// Screen widths >= this trigger the constraint. 600pt covers everything
  /// from iPad mini up; phones in landscape (~844pt on iPhone 14 Pro) also
  /// get the constraint, which is fine because they look better contained.
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.sizeOf(context).width;
    if (w < breakpoint) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Convenience predicate. True on iPad / tablet / wide screens.
/// Use inside build() when a single widget needs to switch shape rather
/// than just be constrained — e.g. grid column count.
bool isWideScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 600;
