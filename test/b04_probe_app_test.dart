import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_service.dart';
import 'package:siraj/features/auth/password_hasher.dart';

import '../integration_test/support/b04_probe_app.dart';
import 'support/auth_test_marker.dart';

class _ReadFailureMarker extends ControlledMarker {
  bool failRead = true;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('isolated test failure');
    return super.read();
  }
}

Future<void> _until(WidgetTester t, Finder finder) async {
  for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await t.pump();
  }
  expect(finder, findsOneWidget);
}

Future<void> _fill(WidgetTester t, String prefix, String password) async {
  await t.enterText(find.byKey(Key('$prefix-username')), 'probe-test-user');
  await t.enterText(find.byKey(Key('$prefix-password')), password);
  if (prefix == 'signup') {
    await t.enterText(find.byKey(const Key('signup-confirmation')), password);
  }
  await t.ensureVisible(find.byKey(Key('$prefix-submit')));
  await t.tap(find.byKey(Key('$prefix-submit')));
  await t.pump();
}

void main() {
  testWidgets('probe creates a real account and shows its test session', (
    t,
  ) async {
    await t.runAsync(() async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final users = UserRepository(db);
      final auth = AuthService(
        users: users,
        passwordHasher: PasswordHasher(iterations: 1000),
        markerStore: ControlledMarker(),
      );
      try {
        await t.pumpWidget(B04ProbeApp(auth: auth, users: users));
        await _until(t, find.byKey(const Key('signup-username')));
        await _fill(t, 'signup', 'synthetic-test-only');
        await _until(t, find.byKey(const Key('probe-session')));
        expect(await users.currentAccount(), isNotNull);
        expect(await auth.checkSession(auth.activeSession!), isTrue);
        expect(find.textContaining('B-04'), findsWidgets);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await db.close();
      }
    });
  });

  testWidgets(
    'probe restores, logs out, rejects wrong login and deletes safely',
    (t) async {
      await t.runAsync(() async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final users = UserRepository(db);
        final marker = ControlledMarker();
        final auth = AuthService(
          users: users,
          passwordHasher: PasswordHasher(iterations: 1000),
          markerStore: marker,
        );
        try {
          final old = await auth.createAccount(
            username: 'probe-test-user',
            password: 'synthetic-test-only',
            confirmation: 'synthetic-test-only',
          );
          await db.customStatement(
            "INSERT INTO installed_resource(resource_id,kind,state,updated_at) VALUES ('probe-shared','PDF','MISSING','2026-10-23T00:00:00Z')",
          );
          await t.pumpWidget(B04ProbeApp(auth: auth, users: users));
          await _until(t, find.byKey(const Key('probe-session')));
          await t.tap(find.byKey(const Key('probe-logout')));
          await _until(t, find.byKey(const Key('login-username')));
          expect(await auth.checkSession(old), false);
          await _fill(t, 'login', 'deliberately-wrong');
          await _until(t, find.byKey(const Key('login-error')));
          expect(auth.activeSession, isNull);
          await _fill(t, 'login', 'synthetic-test-only');
          await _until(t, find.byKey(const Key('probe-session')));
          await t.tap(find.byKey(const Key('probe-delete')));
          await t.pumpAndSettle();
          expect(await users.currentAccount(), isNotNull);
          await t.tap(find.byKey(const Key('probe-confirm-delete')));
          await _until(t, find.byKey(const Key('signup-username')));
          expect(await users.currentAccount(), isNull);
          expect(marker.raw, isNull);
          final n = await db
              .customSelect('SELECT COUNT(*) AS n FROM installed_resource')
              .getSingle();
          expect(n.read<int>('n'), 1);
        } finally {
          await t.pumpWidget(const SizedBox.shrink());
          await db.close();
        }
      });
    },
  );

  testWidgets(
    'probe storage failure fails closed and supports explicit retry',
    (t) async {
      await t.runAsync(() async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final users = UserRepository(db);
        final marker = _ReadFailureMarker();
        final auth = AuthService(
          users: users,
          passwordHasher: PasswordHasher(iterations: 1000),
          markerStore: marker,
        );
        try {
          await auth.createAccount(
            username: 'probe-test-user',
            password: 'synthetic-test-only',
            confirmation: 'synthetic-test-only',
          );
          await t.pumpWidget(B04ProbeApp(auth: auth, users: users));
          await _until(t, find.byKey(const Key('probe-error')));
          expect(find.byKey(const Key('probe-session')), findsNothing);
          expect(find.byKey(const Key('signup-username')), findsNothing);
          marker.failRead = false;
          await t.tap(find.byKey(const Key('probe-retry')));
          await _until(t, find.byKey(const Key('probe-session')));
        } finally {
          await t.pumpWidget(const SizedBox.shrink());
          await db.close();
        }
      });
    },
  );
}
