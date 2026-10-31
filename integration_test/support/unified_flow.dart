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
    if (finder.evaluate().isEmpty) {
      // Only fixed UI errors and presence booleans; never credentials/nonces.
      final error = find.byKey(const Key('login-error'));
      bool populated(String key) {
        final field = find.byKey(Key(key));
        return field.evaluate().length == 1 &&
            (tester.widget<TextFormField>(field).controller?.text.isNotEmpty ??
                false);
      }

      debugPrint(
        'SIRAJ_NATIVE_WAIT_FAILED login_error='
        '${error.evaluate().isEmpty ? 'none' : tester.widget<Text>(error).data} '
        'username_present=${populated('login-username')} '
        'password_present=${populated('login-password')}',
      );
    }
    expect(finder, findsWidgets);
  }

  bool _enabled(Finder finder) => switch (tester.widget(finder)) {
    ButtonStyleButton(:final onPressed) => onPressed != null,
    IconButton(:final onPressed) => onPressed != null,
    TextFormField(:final enabled) => enabled != false,
    TextField(:final enabled, :final readOnly) => enabled != false && !readOnly,
    _ => true,
  };

  Future<void> enterText(Finder finder, String value) async {
    await until(finder);
    var stable = 0;
    for (var attempt = 0; attempt < 30 && stable < 2; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      stable = finder.evaluate().length == 1 && _enabled(finder)
          ? stable + 1
          : 0;
    }
    expect(stable, 2, reason: 'Wait for an enabled form before entering text');
    await tester.enterText(finder, value);
    await tester.pump();
    final editable = find.descendant(
      of: finder,
      matching: find.byType(EditableText),
    );
    expect(editable, findsOneWidget);
    expect(
      tester.widget<EditableText>(editable).controller.text == value,
      isTrue,
      reason: 'Synthetic test input must be accepted exactly once',
    );
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
      if (finder.evaluate().length != 1) {
        stable = 0;
        continue;
      }
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
              _enabled(finder) &&
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
