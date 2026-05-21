// Smoke test for the Boyce Armory app.
//
// We don't fully boot the real app here because it requires Firebase to be
// initialized. This test just verifies that BoyceArmoryApp is constructible
// inside a ProviderScope (catches obvious import/wiring regressions).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boyce_armory/app.dart';

void main() {
  testWidgets('BoyceArmoryApp can be constructed', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BoyceArmoryApp()),
    );
    // Pump a single frame; we don't await settle() because the splash screen
    // has an indefinite progress indicator.
    await tester.pump();
    expect(find.byType(BoyceArmoryApp), findsOneWidget);
  });
}
