import 'package:flutter/material.dart';
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
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
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
