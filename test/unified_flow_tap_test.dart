import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/support/unified_flow.dart';

void main() {
  testWidgets(
    'driver waits for delayed native-layout coverage to clear before one real tap',
    (tester) async {
      final covered = ValueNotifier(true);
      var taps = 0;
      final timer = Timer(
        const Duration(milliseconds: 450),
        () => covered.value = false,
      );
      addTearDown(timer.cancel);
      addTearDown(covered.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: covered,
              builder: (context, blocked, _) => Stack(
                children: [
                  Center(
                    child: FilledButton(
                      key: const Key('delayed-submit'),
                      onPressed: () => taps++,
                      child: const Text('Submit'),
                    ),
                  ),
                  if (blocked)
                    const Positioned.fill(
                      child: AbsorbPointer(
                        child: ColoredBox(color: Colors.transparent),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await UnifiedFlow(tester).tap(find.byKey(const Key('delayed-submit')));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'driver rejects a permanently covered target without invoking it',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Center(
                  child: FilledButton(
                    key: const Key('covered-submit'),
                    onPressed: () => taps++,
                    child: const Text('Submit'),
                  ),
                ),
                const Positioned.fill(
                  child: AbsorbPointer(
                    child: ColoredBox(color: Colors.transparent),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await expectLater(
        UnifiedFlow(tester).tap(find.byKey(const Key('covered-submit'))),
        throwsA(isA<TestFailure>()),
      );
      expect(taps, 0);
    },
  );
}
