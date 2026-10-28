import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/app_preferences.dart';
import 'package:siraj/app/app_session_controller.dart';
import 'package:siraj/app/siraj_app.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/database_runtime.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'support/auth_test_marker.dart';
import 'support/pump_real_future.dart';

class _Preferences implements AppPreferencesStore {
  @override
  Future<AppPreferences> read() async => const AppPreferences();
  @override
  Future<void> write(AppPreferences value) async {}
}

/// Actual unified app composition at V2's content viewport after excluding the
/// reference's simulated phone/OS chrome. No demo science/books are injected.
void main() {
  setUpAll(() async {
    await (FontLoader(
      'NotoSansArabic',
    )..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final dark in [false, true]) {
    testWidgets(
      'all reachable real app reference screens AR ${dark ? 'dark' : 'light'} 380x737',
      (t) async {
        t.view.physicalSize = const Size(380, 737);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final runtime = DatabaseRuntime(
          createDatabase: () => AppDatabase.forTesting(NativeDatabase.memory()),
        );
        final session = AppSessionController(
          runtime: runtime,
          markerStore: ControlledMarker(),
          passwordHasher: PasswordHasher(iterations: 2),
        );
        final prefs = AppPreferencesController(_Preferences());
        await prefs.ready;
        await pumpRealFuture(
          t,
          prefs.setTheme(dark ? ThemeMode.dark : ThemeMode.light),
        );
        await t.runAsync(session.initialize);
        try {
          await t.pumpWidget(
            RepaintBoundary(
              key: const Key('reference-golden'),
              child: SirajApp(sessionController: session, preferences: prefs),
            ),
          );
          Future<void> flush() async {
            for (var i = 0; i < 8; i++) {
              await t.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 15)),
              );
              await t.pump(const Duration(milliseconds: 50));
            }
            await t.pumpAndSettle(
              const Duration(milliseconds: 100),
              EnginePhase.sendSemanticsUpdate,
              const Duration(seconds: 2),
            );
          }

          Future<void> capture(String name) async {
            await flush();
            expect(t.takeException(), isNull);
            expect(
              Theme.of(t.element(find.byType(Scaffold).last)).brightness,
              dark ? Brightness.dark : Brightness.light,
            );
            await expectLater(
              find.byKey(const Key('reference-golden')),
              matchesGoldenFile(
                'goldens/reference_v2/app_ar_${dark ? 'dark' : 'light'}_$name.png',
              ),
            );
          }

          Future<void> until(Finder finder) async {
            for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
              await t.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 10)),
              );
              await t.pump(const Duration(milliseconds: 100));
            }
            expect(finder, findsWidgets);
          }

          Future<void> tab(int index) async {
            final nav = t.widget<NavigationBar>(find.byType(NavigationBar));
            final destination =
                nav.destinations[index] as NavigationDestination;
            await t.tap(
              find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text(destination.label),
              ),
            );
            await flush();
          }

          await capture('onboard');
          await t.tap(find.text('تخطي'));
          await flush();
          await capture('auth');
          await t.runAsync(
            () => session.createAccount(
              username: 'طالب الاختبار',
              password: 'test-only-password',
              confirmation: 'test-only-password',
            ),
          );
          await until(find.byKey(const Key('open-chat')));
          await pumpRealFuture(
            t,
            prefs.setTheme(dark ? ThemeMode.dark : ThemeMode.light),
          );
          await capture('home');
          await tab(1);
          await capture('history_empty');
          await t.tap(find.byKey(const Key('history-new-chat')));
          await flush();
          await capture('chat');
          await t.enterText(
            find.byKey(const Key('chat-question-input')),
            'سؤال اصطناعي لا يتوقع إجابة علمية',
          );
          await t.pump();
          await t.tap(find.byKey(const Key('chat-send-enabled')));
          await until(find.byKey(const Key('chat-saved-question')));
          await capture('chat_error');
          await t.tap(find.byType(BackButton));
          await flush();
          await capture('history');
          await tab(2);
          await capture('library');
          await tab(3);
          await capture('quiz');
          await tab(0);
          await t.ensureVisible(find.byKey(const Key('open-resource-status')));
          await flush();
          await t.tap(find.byKey(const Key('open-resource-status')));
          await flush();
          await capture('resources');
          await t.tap(find.byType(BackButton));
          await flush();
          await t.tap(find.byKey(const Key('open-settings')));
          await flush();
          await capture('settings');
          await t.ensureVisible(find.byKey(const Key('settings-logout')));
          await flush();
          await t.tap(find.byKey(const Key('settings-logout')));
          await flush();
          await capture('logout');
          await t.tap(find.text('إلغاء').last);
          await flush();
          await t.ensureVisible(find.byKey(const Key('settings-delete')));
          await flush();
          await t.tap(find.byKey(const Key('settings-delete')));
          await flush();
          expect(
            t
                .widget<FilledButton>(
                  find.byKey(const Key('confirm-account-action')),
                )
                .onPressed,
            isNull,
          );
          await capture('delete');
          await t.tap(find.byKey(const Key('delete-account-checkbox')));
          await flush();
          await capture('delete_acknowledged');
          await t.tap(find.text('إلغاء').last);
          await flush();
          await t.ensureVisible(find.byKey(const Key('settings-logout')));
          await flush();
          await t.tap(find.byKey(const Key('settings-logout')));
          await flush();
          await t.tap(find.byKey(const Key('confirm-account-action')));
          await until(find.byKey(const Key('login-submit')));
          await capture('login');
        } finally {
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          prefs.dispose();
          session.dispose();
          await t.runAsync(runtime.close);
        }
      },
    );
  }
}
