import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/auth_service.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'support/auth_test_marker.dart';
import 'support/auth_test_repository.dart';

void main() {
  late AppDatabase db;
  late UserRepository users;
  late ControlledMarker marker;
  late AuthService auth;
  AuthService service() => AuthService(
    users: users,
    passwordHasher: PasswordHasher(iterations: 10), // isolated tests only
    markerStore: marker,
  );
  Future<AuthSession> create() => auth.createAccount(
    username: 'test-user',
    password: 'test-only',
    confirmation: 'test-only',
  );
  Future<AuthSession> login() =>
      auth.login(username: 'test-user', password: 'test-only');
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    users = UserRepository(db);
    marker = ControlledMarker();
    auth = service();
  });
  tearDown(() async {
    if (!marker.release.isCompleted) marker.release.complete();
    await db.close();
  });

  test('overlapping logins cannot publish mismatched DB and marker', () async {
    await create();
    await auth.logout();
    marker.pauseNext = true;
    final first = login();
    await marker.entered.future;
    Object? secondError;
    try {
      await login();
    } catch (e) {
      secondError = e;
    }
    marker.release.complete();
    await first;
    expect(secondError, isA<AuthFailure>());
    expect(await service().restoreSession(), isNotNull);
  });

  test(
    'Logout cancels in-flight reauthentication without resurrecting a session',
    () async {
      await create();
      marker.pauseNext = true;
      Object? loginError;
      final pending = login().then<void>(
        (_) {},
        onError: (Object e) {
          loginError = e;
        },
      );
      await marker.entered.future;
      Object? logoutError;
      final logout = auth.logout().then<void>(
        (_) {},
        onError: (Object e) {
          logoutError = e;
        },
      );
      marker.release.complete();
      await Future.wait([pending, logout]);
      expect(logoutError, isNull);
      expect(loginError, isA<AuthFailure>());
      expect(auth.activeSession, isNull);
      expect(await service().restoreSession(), isNull);
    },
  );

  test(
    'failed secure write cannot authorize restart even when DB rollback fails',
    () async {
      await create();
      await auth.logout();
      await db.customStatement(
        "CREATE TRIGGER deny_revoke BEFORE UPDATE ON user_profile WHEN NEW.active_session_nonce_hash IS NULL BEGIN SELECT RAISE(ABORT, 'isolated failure'); END;",
      );
      marker.failAfterWrite = true;
      await expectLater(login(), throwsA(isA<AuthFailure>()));
      expect(auth.activeSession, isNull);
      final row = (await users.currentAccount())!;
      expect(row.read<Uint8List?>('active_session_nonce_hash'), isNull);
      expect(await service().restoreSession(), isNull);
    },
  );

  test(
    'Delete drains pending authentication and prevents late recreation',
    () async {
      await create();
      marker.pauseNext = true;
      final pending = expectLater(login(), throwsA(isA<AuthFailure>()));
      await marker.entered.future;
      final deleted = auth.deleteCurrentAccount(confirmed: true);
      marker.release.complete();
      await pending;
      await deleted;
      expect(await users.currentAccount(), isNull);
      expect(await service().restoreSession(), isNull);
    },
  );
  test(
    'Logout drains a committed publication then revokes its exact nonce',
    () async {
      await create();
      final paused = PausedNoncePublish(db);
      users = paused;
      auth = service();
      await auth.restoreSession();
      paused.pause = true;
      final pending = login();
      await paused.committed.future;
      final logout = auth.logout();
      paused.pause = false;
      paused.release.complete();
      await pending;
      await logout;
      expect(await service().restoreSession(), isNull);
    },
  );
  test(
    'database failure after secure write does not authorize new marker',
    () async {
      await create();
      await auth.logout();
      await db.customStatement(
        "CREATE TRIGGER deny_publish BEFORE UPDATE ON user_profile WHEN NEW.active_session_nonce_hash IS NOT NULL BEGIN SELECT RAISE(ABORT, 'isolated failure'); END;",
      );
      await expectLater(
        login(),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.databaseFailure,
          ),
        ),
      );
      expect(await service().restoreSession(), isNull);
      expect(await users.currentAccount(), isNotNull);
    },
  );
  test(
    'authentication lane also fences another service using the same database',
    () async {
      await create();
      await auth.logout();
      marker.pauseNext = true;
      final pending = login();
      await marker.entered.future;
      await expectLater(
        service().login(username: 'test-user', password: 'test-only'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.operationInProgress,
          ),
        ),
      );
      marker.release.complete();
      await pending;
      expect(await service().restoreSession(), isNotNull);
    },
  );
  test(
    'explicit cancellation before signup KDF publishes no account',
    () async {
      auth = AuthService(
        users: users,
        passwordHasher: PasswordHasher(iterations: 600000),
        markerStore: marker,
        onDiagnosticStep: (step) {
          if (step == 'signup.kdf_started') auth.cancelPendingAuthentication();
        },
      );
      await expectLater(
        create(),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.operationCancelled,
          ),
        ),
      );
      expect(await users.currentAccount(), isNull);
      expect(marker.raw, isNull);
    },
  );
}
