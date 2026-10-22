import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/auth_service.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'support/auth_test_marker.dart';

void main() {
  test(
    '600k real KDF and file SQLite: signup, wrong/correct login, reopen, logout, delete',
    () async {
      final dir = await Directory.systemTemp.createTemp('siraj-b04-secure-');
      final file = File('${dir.path}/account.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      final marker =
          ControlledMarker(); // Storage boundary only; no native claim.
      AuthService make() => AuthService(
        users: UserRepository(db),
        passwordHasher: PasswordHasher(
          iterations: PasswordHasher.candidateIterations,
        ),
        markerStore: marker,
      );
      var auth = make();
      try {
        final original = await auth.createAccount(
          username: 'synthetic-user',
          password: 'synthetic-only',
          confirmation: 'synthetic-only',
        );
        expect(await auth.checkSession(original), true);
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        auth = make();
        final restored = await auth.restoreSession();
        expect(restored!.sessionNonce, original.sessionNonce);
        await auth.logout();
        expect(await make().restoreSession(), isNull);
        await expectLater(
          auth.login(username: 'synthetic-user', password: 'wrong'),
          throwsA(isA<AuthFailure>()),
        );
        final login = await auth.login(
          username: 'synthetic-user',
          password: 'synthetic-only',
        );
        expect(await auth.checkSession(login), true);
        await db.customStatement(
          "INSERT INTO installed_resource(resource_id,kind,state,updated_at) VALUES ('shared-test-pdf','PDF','MISSING','2026-10-23T00:00:00Z')",
        );
        await auth.deleteCurrentAccount(confirmed: true);
        expect(await UserRepository(db).currentAccount(), isNull);
        expect(
          (await db
                  .customSelect('SELECT COUNT(*) AS n FROM installed_resource')
                  .getSingle())
              .read<int>('n'),
          1,
        );
        expect(await auth.checkSession(login), false);
        expect(await make().restoreSession(), isNull);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
