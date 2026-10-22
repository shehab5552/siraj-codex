import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drain Drift's deferred query-cache cleanup while the fake clock is active.
void chatWidgetTest(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
