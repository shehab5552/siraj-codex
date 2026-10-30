import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Timing follows actual UI conditions; no real Auth/SQLite/native port is faked.
class UnifiedFlow {
  const UnifiedFlow(this.tester);
  final WidgetTester tester;
  static const username = 'Synthetic restart student';
  static const password = 'SIRAJ_restart_test_only_2026!';
  static const question = 'SIRAJ_SYNTHETIC_FORCE_STOP_USER_MESSAGE';
  Future<void> until(Finder finder) async {
    final watch = Stopwatch()..start();
    while (finder.evaluate().isEmpty &&
        watch.elapsed < const Duration(seconds: 90)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tap(Finder finder) async {
    await until(finder);
    // Native IME callbacks can arrive after Flutter has no scheduled frames.
    // Require two actual hit-testable frames; never force a covered coordinate.
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    var stable = 0;
    for (var attempt = 0; attempt < 30 && stable < 2; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.view.viewInsets.bottom > 0) {
        stable = 0;
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        continue;
      }
      await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
      await tester.pump(const Duration(milliseconds: 100));
      stable =
          tester.view.viewInsets.bottom == 0 &&
              finder.hitTestable().evaluate().isNotEmpty
          ? stable + 1
          : 0;
    }
    if (stable < 2) {
      debugPrint(
        'SIRAJ_NATIVE_TARGET_NOT_READY rect=${tester.getRect(finder)} '
        'size=${tester.view.physicalSize} dpr=${tester.view.devicePixelRatio} '
        'insets=${tester.view.viewInsets}',
      );
    }
    expect(
      stable,
      2,
      reason: 'Target must be stably hit-testable after native layout settles',
    );
    expect(finder.hitTestable(), findsWidgets);
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> tab(int index) async {
    final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final destination = nav.destinations[index] as NavigationDestination;
    await tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(destination.label),
      ),
    );
    await tester.pumpAndSettle();
  }
}
