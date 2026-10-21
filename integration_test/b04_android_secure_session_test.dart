import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/auth_service.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'package:siraj/features/auth/session_marker_store.dart';

/// Disposable scope: never reads or writes the production session marker.
/// Uses SIRAJ's direct AndroidKeyStore AES-256-GCM channel.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'B-04 Android: secure marker, SQLite reopen, logout and delete',
    (tester) async {
      final finished = await tester.runAsync(() async {
        const markerStore = KeystoreSessionMarkerStore.forTesting();
        final temp = await Directory.systemTemp.createTemp('siraj_b04_auth_');
        final file = File('${temp.path}${Platform.pathSeparator}auth.sqlite');
        AppDatabase? db;

        // Test-only fast KDF. DO NOT use 1000 iterations for production.
        final hasher = PasswordHasher(iterations: 1000);
        const username = 'طالب اختبار سراج';
        const password = 'SIRAJ_B04_Device_Test_Only_2026!';
        const stamp = '2026-10-21T00:00:00.000Z';

        try {
          debugPrint('SIRAJ_B04_ACCEPT step=secure_clear_started');
          await markerStore.clear();
          debugPrint('SIRAJ_B04_ACCEPT step=secure_clear_passed');
          db = AppDatabase.forTesting(NativeDatabase(file));
          var users = UserRepository(db);
          var auth = AuthService(
            users: users,
            passwordHasher: hasher,
            markerStore: markerStore,
            onDiagnosticStep: (step) => debugPrint('SIRAJ_B04_CORE step=$step'),
          );

          debugPrint('SIRAJ_B04_ACCEPT step=signup_started');
          final original = await auth
              .createAccount(
                username: username,
                password: password,
                confirmation: password,
              )
              .timeout(const Duration(seconds: 25));
          expect(await auth.checkSession(original), isTrue);
          expect(await markerStore.read(), isNotNull);
          debugPrint('SIRAJ_B04_ANDROID step=signup_secure_marker PASS');

          // Reopen the same isolated SQLite file and create a NEW AuthService.
          // This verifies persistence across object recreation, not a reboot.
          debugPrint('SIRAJ_B04_ACCEPT step=reopen_started');
          await db.close();
          db = null;
          db = AppDatabase.forTesting(NativeDatabase(file));
          users = UserRepository(db);
          auth = AuthService(
            users: users,
            passwordHasher: hasher,
            markerStore: markerStore,
            onDiagnosticStep: (step) => debugPrint('SIRAJ_B04_CORE step=$step'),
          );
          final restored = await auth.restoreSession();
          expect(restored, isNotNull);
          expect(restored!.userId, original.userId);
          expect(restored.accountEpoch, original.accountEpoch);
          expect(await auth.checkSession(restored), isTrue);
          debugPrint('SIRAJ_B04_ANDROID step=restore_after_reopen PASS');

          debugPrint('SIRAJ_B04_ACCEPT step=logout_started');
          await auth.logout();
          expect(await auth.checkSession(restored), isFalse);
          expect(await markerStore.read(), isNull);
          final afterLogout = AuthService(
            users: users,
            passwordHasher: hasher,
            markerStore: markerStore,
            onDiagnosticStep: (step) => debugPrint('SIRAJ_B04_CORE step=$step'),
          );
          expect(await afterLogout.restoreSession(), isNull);
          debugPrint('SIRAJ_B04_ANDROID step=logout_invalidates PASS');

          debugPrint('SIRAJ_B04_ACCEPT step=login_started');
          final loggedIn = await afterLogout.login(
            username: username,
            password: password,
          );
          expect(await afterLogout.checkSession(loggedIn), isTrue);

          // Shared resources must survive account deletion.
          await db.customInsert(
            '''
            INSERT INTO installed_resource
              (resource_id,kind,state,updated_at)
            VALUES ('b04-test-book','PDF','MISSING',?)
          ''',
            variables: [Variable.withString(stamp)],
          );

          await expectLater(
            afterLogout.deleteCurrentAccount(confirmed: false),
            throwsA(
              isA<AuthFailure>().having(
                (failure) => failure.code,
                'code',
                AuthFailureCode.confirmationRequired,
              ),
            ),
          );
          expect(await users.currentAccount(), isNotNull);
          await afterLogout.deleteCurrentAccount(confirmed: true);
          expect(await users.currentAccount(), isNull);
          expect(await markerStore.read(), isNull);
          final resourceCount = await db
              .customSelect('SELECT COUNT(*) AS n FROM installed_resource')
              .getSingle();
          expect(resourceCount.read<int>('n'), 1);
          expect(await afterLogout.checkSession(loggedIn), isFalse);
          debugPrint('SIRAJ_B04_ANDROID step=delete_preserves_resource PASS');
          return true;
        } finally {
          // Cleanup must not hide an earlier failure with a second hang.
          try {
            if (db != null) {
              await db.close().timeout(const Duration(seconds: 8));
            }
          } catch (_) {
            debugPrint('SIRAJ_B04_ACCEPT cleanup_db_incomplete');
          }
          try {
            await markerStore.clear().timeout(const Duration(seconds: 8));
          } catch (_) {
            debugPrint('SIRAJ_B04_ACCEPT cleanup_marker_incomplete');
          }
          try {
            if (await temp.exists()) await temp.delete(recursive: true);
          } catch (_) {
            debugPrint('SIRAJ_B04_ACCEPT cleanup_temp_incomplete');
          }
        }
      });
      expect(finished, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
