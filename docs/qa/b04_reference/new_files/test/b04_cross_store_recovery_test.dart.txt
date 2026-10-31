import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/auth_service.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'package:siraj/features/auth/startup_session_resolver.dart';
import 'support/auth_test_marker.dart';

class DelayedRead extends ControlledMarker {
  bool paused = false;
  final reading = Completer<void>();
  final readRelease = Completer<void>();
  @override
  Future<String?> read() async {
    final captured = raw;
    if (paused) {
      reading.complete();
      await readRelease.future;
    }
    return captured;
  }
}

void main() {
  test(
    'failed pending reauthentication preserves private authority for queued Logout',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final users = UserRepository(db);
      final marker = ControlledMarker();
      final auth = AuthService(
        users: users,
        passwordHasher: PasswordHasher(iterations: 10),
        markerStore: marker,
      );
      try {
        await auth.createAccount(
          username: 'synthetic',
          password: 'test-only',
          confirmation: 'test-only',
        );
        marker.pauseNext = true;
        marker.failBeforeWrite = true;
        final login = expectLater(
          auth.login(username: 'synthetic', password: 'test-only'),
          throwsA(isA<AuthFailure>()),
        );
        await marker.entered.future;
        final logout = auth.logout();
        marker.release.complete();
        await login;
        await logout;
        marker.failBeforeWrite = false;
        expect(auth.activeSession, isNull);
        expect(await auth.restoreSession(), isNull);
      } finally {
        if (!marker.release.isCompleted) marker.release.complete();
        await db.close();
      }
    },
  );
  test(
    'Startup stale cleanup cannot race a fresh credential publication',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final users = UserRepository(db);
      final marker = DelayedRead();
      final auth = AuthService(
        users: users,
        passwordHasher: PasswordHasher(iterations: 10),
        markerStore: marker,
      );
      try {
        await auth.createAccount(
          username: 'synthetic',
          password: 'test-only',
          confirmation: 'test-only',
        );
        await auth.logout();
        marker.raw = 'malformed';
        marker.paused = true;
        final resolver = StartupSessionResolver(
          users: users,
          markerStore: marker,
        );
        final startup = resolver.resolve();
        await marker.reading.future;
        Object? error;
        try {
          await auth.login(username: 'synthetic', password: 'test-only');
        } catch (e) {
          error = e;
        }
        marker.readRelease.complete();
        marker.paused = false;
        await startup;
        expect(
          error,
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.operationInProgress,
          ),
        );
        await auth.login(username: 'synthetic', password: 'test-only');
        expect((await resolver.resolve()).status, StartupStatus.authenticated);
        expect(marker.raw, isNotNull);
      } finally {
        if (!marker.readRelease.isCompleted) marker.readRelease.complete();
        await db.close();
      }
    },
  );
}
