import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/data/conversation_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/auth_service.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'package:siraj/features/auth/session_guard.dart';
import 'package:siraj/features/auth/signup_page.dart';
import 'package:siraj/features/auth/login_page.dart';
import 'package:siraj/features/auth/startup_session_resolver.dart';
import 'package:siraj/features/chat/conversation_draft_controller.dart';
import 'support/auth_test_repository.dart';
import 'support/auth_test_marker.dart';

class FailedRollback extends PausedNoncePublish {
  FailedRollback(super.db);
  var calls = 0;
  @override
  Future<int> compareAndSetNonceHash({
    required String userId,
    required String accountEpoch,
    required Uint8List? expectedNonceHash,
    required Uint8List hash,
    required String nowUtc,
    bool Function()? isRequestCurrent,
  }) {
    if (++calls > 1) throw StateError('isolated rollback failure');
    return super.compareAndSetNonceHash(
      userId: userId,
      accountEpoch: accountEpoch,
      expectedNonceHash: expectedNonceHash,
      hash: hash,
      nowUtc: nowUtc,
      isRequestCurrent: isRequestCurrent,
    );
  }
}

void main() {
  late AppDatabase db;
  late UserRepository users;
  late ControlledMarker marker;
  late AuthService auth;
  AuthService make() => AuthService(
    users: users,
    passwordHasher: PasswordHasher(iterations: 10),
    markerStore: marker,
  );
  Future<AuthSession> create() => auth.createAccount(
    username: 'synthetic',
    password: 'test-only',
    confirmation: 'test-only',
  );
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    users = UserRepository(db);
    marker = ControlledMarker();
    auth = make();
  });
  tearDown(() => db.close());
  test(
    'failed Logout blocks retained-session writes and permits direct retry',
    () async {
      final session = await create();
      await db.customStatement(
        "CREATE TRIGGER deny_logout BEFORE UPDATE ON user_profile WHEN NEW.active_session_nonce_hash IS NULL BEGIN SELECT RAISE(ABORT, 'isolated DB failure'); END;",
      );
      await expectLater(auth.logout(), throwsA(isA<AuthFailure>()));
      expect(await auth.checkSession(session), false);
      final draft = ConversationDraftController(
        conversations: ConversationRepository(db),
        guard: SessionGuard(users),
      );
      await expectLater(
        draft.commitFirstQuestion(session: session, question: 'late'),
        throwsA(anything),
      );
      await db.customStatement('DROP TRIGGER deny_logout');
      await auth.logout();
      expect(await make().restoreSession(), isNull);
    },
  );
  test(
    'Startup retries stale marker cleanup after Logout and Delete',
    () async {
      await create();
      marker.failClear = true;
      await auth.logout();
      marker.failClear = false;
      final resolver = StartupSessionResolver(
        users: users,
        markerStore: marker,
      );
      expect((await resolver.resolve()).status, StartupStatus.loginRequired);
      expect(marker.raw, isNull);
      await auth.login(username: 'synthetic', password: 'test-only');
      marker.failClear = true;
      await auth.deleteCurrentAccount(confirmed: true);
      marker.failClear = false;
      expect((await resolver.resolve()).status, StartupStatus.accountRequired);
      expect(marker.raw, isNull);
    },
  );
  test(
    'durable session publication wins Cancel then Logout revokes it without rollback',
    () async {
      await create();
      final repo = FailedRollback(db);
      users = repo;
      auth = make();
      await auth.restoreSession();
      repo.pause = true;
      Object? loginError;
      Object? logoutError;
      final pending = auth
          .login(username: 'synthetic', password: 'test-only')
          .then<void>(
            (_) {},
            onError: (Object e) {
              loginError = e;
            },
          );
      await repo.committed.future;
      final logout = auth.logout().then<void>(
        (_) {},
        onError: (Object e) {
          logoutError = e;
        },
      );
      repo.release.complete();
      await Future.wait([pending, logout]);
      expect(loginError, isNull);
      expect(logoutError, isNull);
      expect(repo.calls, 1);
      expect(await make().restoreSession(), isNull);
    },
  );
  testWidgets(
    'Signup saved account with interrupted session reconciles to Login',
    (t) async {
      await t.runAsync(() async {
        auth = AuthService(
          users: users,
          passwordHasher: PasswordHasher(iterations: 10),
          markerStore: marker,
          onDiagnosticStep: (step) {
            if (step == 'signup.db_create_passed') {
              auth.cancelPendingAuthentication();
            }
          },
        );
        Future<void>? pending;
        await t.pumpWidget(
          MaterialApp(
            home: SignupPage(
              onLoginAfterCreation: ({required username, required password}) {
                pending = auth
                    .login(username: username, password: password)
                    .then<void>((_) {});
                return pending!;
              },
              onCreateAccount:
                  ({
                    required username,
                    required password,
                    required confirmation,
                  }) {
                    pending = auth
                        .createAccount(
                          username: username,
                          password: password,
                          confirmation: confirmation,
                        )
                        .then<void>((_) {});
                    return pending!;
                  },
            ),
          ),
        );
        await t.enterText(
          find.byKey(const Key('signup-username')),
          'synthetic',
        );
        await t.enterText(
          find.byKey(const Key('signup-password')),
          'test-only',
        );
        await t.enterText(
          find.byKey(const Key('signup-confirmation')),
          'test-only',
        );
        await t.ensureVisible(find.byKey(const Key('signup-submit')));
        await t.tap(find.byKey(const Key('signup-submit')));
        await t.pump();
        await expectLater(pending, throwsA(isA<AuthFailure>()));
        await t.pumpAndSettle();
        expect(await users.currentAccount(), isNotNull);
        expect(find.byKey(const Key('signup-submit')), findsNothing);
        expect(find.byType(LoginPage), findsOneWidget);
        await t.enterText(find.byKey(const Key('login-username')), 'synthetic');
        await t.enterText(find.byKey(const Key('login-password')), 'test-only');
        await t.ensureVisible(find.byKey(const Key('login-submit')));
        await t.tap(find.byKey(const Key('login-submit')));
        await t.pump();
        await pending;
        await t.pumpAndSettle();
        expect(await auth.checkSession(auth.activeSession!), true);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      });
    },
  );
  test(
    'queued Logout fences the committed replacement before a failing validation read',
    () async {
      await create();
      final repo = PausedNoncePublish(db);
      users = repo;
      auth = make();
      await auth.restoreSession();
      repo.pause = true;
      final pending = auth.login(username: 'synthetic', password: 'test-only');
      await repo.committed.future;
      final logout = expectLater(auth.logout(), throwsA(isA<AuthFailure>()));
      repo.failNextRead = true;
      repo.release.complete();
      final session = await pending;
      await logout;
      expect(auth.activeSession, isNull);
      expect(await auth.checkSession(session), false);
      await auth.logout();
      expect(await make().restoreSession(), isNull);
    },
  );
}
