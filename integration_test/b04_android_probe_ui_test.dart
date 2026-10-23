import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/conversation_repository.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_service.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'package:siraj/features/auth/session_guard.dart';
import 'package:siraj/features/auth/session_marker_store.dart';
import 'package:siraj/features/chat/conversation_draft_controller.dart';

import 'support/b04_probe_app.dart';

Future<void> _until(WidgetTester tester, Finder target) async {
  final watch = Stopwatch()..start();
  while (target.evaluate().isEmpty && watch.elapsed.inSeconds < 90) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump();
  }
  expect(target, findsOneWidget);
}

Future<void> _submit(WidgetTester tester, String page, String password) async {
  await tester.enterText(
    find.byKey(Key('$page-username')),
    'b04-device-ui-only',
  );
  await tester.enterText(find.byKey(Key('$page-password')), password);
  if (page == 'signup') {
    await tester.enterText(
      find.byKey(const Key('signup-confirmation')),
      password,
    );
  }
  await tester.ensureVisible(find.byKey(Key('$page-submit')));
  await tester.tap(find.byKey(Key('$page-submit')));
  await tester.pump();
}

Future<int> _count(AppDatabase db, String table) async =>
    (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
        .read<int>('n');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'Android UI: real candidate KDF, Keystore, login, logout, delete cascade',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      await tester.runAsync(() async {
        const marker = KeystoreSessionMarkerStore.forTesting();
        final temp = await Directory.systemTemp.createTemp('b04-native-ui-');
        final db = AppDatabase.forTesting(
          NativeDatabase(File('${temp.path}/probe.sqlite')),
        );
        final users = UserRepository(db);
        final auth = AuthService(
          users: users,
          passwordHasher: PasswordHasher(
            iterations: PasswordHasher.candidateIterations,
          ),
          markerStore: marker,
        );
        const password = 'synthetic-device-ui-only-2026!';
        try {
          await marker.clear();
          await tester.pumpWidget(B04ProbeApp(auth: auth, users: users));
          await _until(tester, find.byKey(const Key('signup-username')));
          await _submit(tester, 'signup', password);
          expect(find.byType(CircularProgressIndicator), findsWidgets);
          await tester.pump(const Duration(milliseconds: 32));
          await _until(tester, find.byKey(const Key('probe-session')));
          final original = auth.activeSession!;
          expect(await marker.read(), isNotNull);
          await tester.tap(find.byKey(const Key('probe-logout')));
          await _until(tester, find.byKey(const Key('login-username')));
          expect(await auth.checkSession(original), isFalse);
          await _submit(tester, 'login', 'deliberately-wrong');
          await _until(tester, find.byKey(const Key('login-error')));
          expect(auth.activeSession, isNull);
          await _submit(tester, 'login', password);
          await _until(tester, find.byKey(const Key('probe-session')));
          final current = auth.activeSession!;
          await ConversationDraftController(
            conversations: ConversationRepository(db),
            guard: SessionGuard(users),
          ).commitFirstQuestion(
            session: current,
            question: 'synthetic persistence check; no Tutor call',
          );
          await db.customStatement(
            "INSERT INTO installed_resource(resource_id,kind,state,updated_at) VALUES ('b04-ui-shared','PDF','MISSING','2026-10-23T00:00:00Z')",
          );
          expect(await _count(db, 'conversation'), 1);
          expect(await _count(db, 'message'), 1);
          await tester.tap(find.byKey(const Key('probe-delete')));
          await tester.pumpAndSettle();
          expect(await _count(db, 'user_profile'), 1);
          await tester.tap(find.byKey(const Key('probe-confirm-delete')));
          await _until(tester, find.byKey(const Key('signup-username')));
          expect(await _count(db, 'user_profile'), 0);
          expect(await _count(db, 'conversation'), 0);
          expect(await _count(db, 'message'), 0);
          expect(await _count(db, 'installed_resource'), 1);
          expect(await marker.read(), isNull);
          expect(await auth.checkSession(current), isFalse);
          debugPrint(
            'SIRAJ_B04_NATIVE_UI PASS signup/loading/wrong-and-correct-login/logout/delete/cascade/resources; NOT physical-device or broad ANR acceptance',
          );
        } finally {
          auth.cancelPendingAuthentication();
          try {
            await tester.pumpWidget(const SizedBox.shrink());
          } catch (_) {
            debugPrint('SIRAJ_B04_NATIVE_UI cleanup_ui_incomplete');
          }
          try {
            await db.close().timeout(const Duration(seconds: 8));
          } catch (_) {
            debugPrint('SIRAJ_B04_NATIVE_UI cleanup_db_incomplete');
          }
          try {
            await marker.clear().timeout(const Duration(seconds: 8));
          } catch (_) {
            debugPrint('SIRAJ_B04_NATIVE_UI cleanup_marker_incomplete');
          }
          try {
            await temp
                .delete(recursive: true)
                .timeout(const Duration(seconds: 8));
          } catch (_) {
            debugPrint('SIRAJ_B04_NATIVE_UI cleanup_temp_incomplete');
          }
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
