import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/app_bootstrap.dart';
import 'package:siraj/app/app_session_controller.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/database_runtime.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'package:siraj/features/auth/startup_session_resolver.dart';
import 'support/auth_test_marker.dart';
import 'package:siraj/features/resources/resource_status_page.dart';

void main() {
  for (final delete in [false, true]) {
    testWidgets(
      'external revocation destroys an open account dialog delete=$delete',
      (tester) async {
        final runtime = DatabaseRuntime(
          createDatabase: () => AppDatabase.forTesting(NativeDatabase.memory()),
        );
        final session = AppSessionController(
          runtime: runtime,
          markerStore: ControlledMarker(),
          passwordHasher: PasswordHasher(iterations: 2),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          session.dispose();
          await tester.runAsync(() => runtime.close());
        });
        await tester.runAsync(() async {
          await session.initialize();
          await session.createAccount(
            username: 'Student',
            password: 'synthetic',
            confirmation: 'synthetic',
          );
        });
        await tester.pumpWidget(
          MaterialApp(home: AppBootstrap(sessionController: session)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open-settings')));
        await tester.pumpAndSettle();
        final action = find.byKey(
          Key(delete ? 'settings-delete' : 'settings-logout'),
        );
        await tester.scrollUntilVisible(action, 160);
        await tester.ensureVisible(action);
        if (!delete) {
          await tester.tap(action);
          Navigator.of(tester.element(action)).pop();
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .descendant(
                  of: find.byType(NavigationBar),
                  matching: find.text('المكتبة الدراسية'),
                )
                .last,
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            2,
            reason:
                'a popup dismissed before its first frame must not leave navigation suspended',
          );
          await tester.tap(
            find
                .descendant(
                  of: find.byType(NavigationBar),
                  matching: find.text('الرئيسية'),
                )
                .last,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('open-settings')));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(action, 160);
          await tester.ensureVisible(action);
        }
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.runAsync(() => session.logout());
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byKey(const Key('login-submit')), findsOneWidget);
      },
    );
  }
  testWidgets('logout destroys nested private routes and preserves account', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final runtime = DatabaseRuntime(createDatabase: () => db);
    final session = AppSessionController(
      runtime: runtime,
      markerStore: ControlledMarker(),
      passwordHasher: PasswordHasher(iterations: 2),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      await runtime.close();
    });
    await tester.runAsync(() => session.initialize());
    await tester.runAsync(
      () => session.createAccount(
        username: 'Student',
        password: 'synthetic',
        confirmation: 'synthetic',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: AppBootstrap(sessionController: session)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.allWidgets.where(
        (w) =>
            w.key?.toString().contains(
              session.decision.session!.sessionNonce,
            ) ==
            true,
      ),
      isEmpty,
      reason: 'session nonce must never be embedded in diagnostic widget keys',
    );
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason: 'V2 keeps the four real destinations on private subroutes',
    );
    await tester.runAsync(() => session.refresh());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('settings-logout')),
      findsOneWidget,
      reason: 'restoring the same session must keep current route',
    );
    await tester.tap(find.byKey(const Key('settings-resources')));
    await tester.pumpAndSettle();
    expect(find.byType(ResourceStatusPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-logout')));
    await tester.tap(find.byKey(const Key('settings-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-account-action')));
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && session.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpAndSettle();
    expect(session.decision.status, StartupStatus.loginRequired);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(find.byKey(const Key('settings-logout')), findsNothing);
    expect(
      Navigator.of(
        tester.element(find.byKey(const Key('login-submit'))),
      ).canPop(),
      isFalse,
    );
  });
  testWidgets('delete confirmation requires checkbox before account service', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final runtime = DatabaseRuntime(createDatabase: () => db);
    final session = AppSessionController(
      runtime: runtime,
      markerStore: ControlledMarker(),
      passwordHasher: PasswordHasher(iterations: 2),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      await runtime.close();
    });
    await tester.runAsync(() => session.initialize());
    await tester.runAsync(
      () => session.createAccount(
        username: 'Student',
        password: 'synthetic',
        confirmation: 'synthetic',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: AppBootstrap(sessionController: session)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-delete')),
      180,
    );
    await tester.tap(find.byKey(const Key('settings-delete')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('confirm-account-action')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('delete-account-checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-account-action')));
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && session.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpAndSettle();
    expect(session.decision.status, StartupStatus.accountRequired);
    expect(find.byKey(const Key('signup-submit')), findsOneWidget);
  });
}
