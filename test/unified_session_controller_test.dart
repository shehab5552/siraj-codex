import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/app_session_controller.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/database_runtime.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'package:siraj/features/auth/startup_session_resolver.dart';
import 'support/auth_test_marker.dart';

void main() {
  test(
    'real signup logout login deletion transitions and preserves shared resources',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final runtime = DatabaseRuntime(createDatabase: () => db);
      final c = AppSessionController(
        runtime: runtime,
        markerStore: ControlledMarker(),
        passwordHasher: PasswordHasher(iterations: 2),
      );
      await c.initialize();
      expect(c.decision.status, StartupStatus.accountRequired);
      await c.createAccount(
        username: 'student',
        password: 'synthetic',
        confirmation: 'synthetic',
      );
      final old = c.decision.session!;
      expect(c.decision.status, StartupStatus.authenticated);
      await db.customInsert(
        "INSERT INTO installed_resource(resource_id,kind,state,updated_at) VALUES('shared','PDF','MISSING','2026-10-25T00:00:00Z')",
      );
      await c.logout();
      expect(c.decision.status, StartupStatus.loginRequired);
      expect(await UserRepository(db).currentAccount(), isNotNull);
      await c.login(username: 'student', password: 'synthetic');
      expect(c.decision.session!.sessionNonce, isNot(old.sessionNonce));
      await c.deleteAccount(confirmed: true);
      expect(c.decision.status, StartupStatus.accountRequired);
      expect(await UserRepository(db).currentAccount(), isNull);
      expect(
        (await db
                .customSelect('SELECT COUNT(*) AS n FROM installed_resource')
                .getSingle())
            .read<int>('n'),
        1,
      );
      c.dispose();
      await runtime.close();
    },
  );
  test('missing approved hasher never creates account', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final runtime = DatabaseRuntime(createDatabase: () => db);
    final c = AppSessionController(
      runtime: runtime,
      markerStore: ControlledMarker(),
    );
    await c.initialize();
    expect(c.canAuthenticate, isFalse);
    await expectLater(
      c.createAccount(username: 's', password: 'p', confirmation: 'p'),
      throwsA(anything),
    );
    expect(await UserRepository(db).currentAccount(), isNull);
    c.dispose();
    await runtime.close();
  });
}
