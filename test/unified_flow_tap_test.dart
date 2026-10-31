import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/support/unified_flow.dart';

void main() {
  testWidgets('driver accepts BackButton default Navigator action', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Root')),
      ),
    );
    navigator.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(leading: const BackButton()),
          body: const Text('Details'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(navigator.currentState!.canPop(), isTrue);
    await UnifiedFlow(tester).tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(navigator.currentState!.canPop(), isFalse);
    expect(find.text('Root'), findsOneWidget);
  });
  for (final (becomesEnabled, formField) in [
    (true, true),
    (false, true),
    (true, false),
    (false, false),
  ]) {
    testWidgets(
      'driver requires enabled input: $becomesEnabled form=$formField',
      (tester) async {
        final enabled = ValueNotifier(false);
        final text = TextEditingController();
        final timer = Timer(
          const Duration(milliseconds: 900),
          () => enabled.value = becomesEnabled,
        );
        addTearDown(timer.cancel);
        addTearDown(enabled.dispose);
        addTearDown(text.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: enabled,
                builder: (context, ready, _) => formField
                    ? TextFormField(
                        key: const Key('enabled-field'),
                        enabled: ready,
                        controller: text,
                      )
                    : TextField(
                        key: const Key('enabled-field'),
                        enabled: ready,
                        controller: text,
                      ),
              ),
            ),
          ),
        );
        final entering = UnifiedFlow(
          tester,
        ).enterText(find.byKey(const Key('enabled-field')), 'Synthetic input');
        if (becomesEnabled) {
          await entering;
          expect(text.text, 'Synthetic input');
        } else {
          await expectLater(entering, throwsA(isA<TestFailure>()));
          expect(text.text, isEmpty);
        }
      },
    );
  }
  testWidgets('driver waits for a visible disabled button to become enabled', (
    tester,
  ) async {
    final enabled = ValueNotifier(false);
    var taps = 0;
    final timer = Timer(
      const Duration(milliseconds: 900),
      () => enabled.value = true,
    );
    addTearDown(timer.cancel);
    addTearDown(enabled.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (context, ready, _) => FilledButton(
              key: const Key('enabled-later'),
              onPressed: ready ? () => taps++ : null,
              child: const Text('Submit'),
            ),
          ),
        ),
      ),
    );
    await UnifiedFlow(tester).tap(find.byKey(const Key('enabled-later')));
    expect(taps, 1);
  });
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
