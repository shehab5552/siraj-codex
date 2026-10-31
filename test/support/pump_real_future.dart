import 'package:flutter_test/flutter_test.dart';

/// Drain real SQLite/filesystem events together with widget-test microtasks.
/// Waiting inside runAsync on an already-started fake-zone cleanup/preference
/// future can deadlock its continuations; do not replace this with a long sleep.
Future<T> pumpRealFuture<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  T? value;
  Object? error;
  StackTrace? stack;
  future.then<void>(
    (result) {
      value = result;
      done = true;
    },
    onError: (Object e, StackTrace s) {
      error = e;
      stack = s;
      done = true;
    },
  );
  for (var i = 0; i < 200 && !done; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(
    done,
    isTrue,
    reason: 'real operation must settle while both event loops progress',
  );
  if (error != null) Error.throwWithStackTrace(error!, stack!);
  return value as T;
}
