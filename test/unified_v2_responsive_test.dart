import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/app_preferences.dart';
import 'package:siraj/app/app_session_controller.dart';
import 'package:siraj/app/siraj_app.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/database_runtime.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'package:siraj/features/settings/account_appearance.dart';
import 'support/auth_test_marker.dart';

class _Device implements AppPreferencesStore {
  @override
  Future<AppPreferences> read() async =>
      const AppPreferences(onboardingComplete: true);
  @override
  Future<void> write(AppPreferences value) async {}
}

void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 1024.0]) {
        testWidgets(
          'unified screens $language ${dark ? "dark" : "light"} $width at 200% text',
          (t) async {
            t.view.physicalSize = Size(width, 800);
            t.view.devicePixelRatio = 1;
            addTearDown(() {
              t.view.resetPhysicalSize();
              t.view.resetDevicePixelRatio();
              t.platformDispatcher.clearTextScaleFactorTestValue();
            });
            t.platformDispatcher.textScaleFactorTestValue = 2;
            final db = AppDatabase.forTesting(NativeDatabase.memory());
            final runtime = DatabaseRuntime(createDatabase: () => db);
            final session = AppSessionController(
              runtime: runtime,
              markerStore: ControlledMarker(),
              passwordHasher: PasswordHasher(iterations: 2),
            );
            await t.runAsync(() async {
              await session.initialize();
              await session.createAccount(
                username: 'synthetic',
                password: 'synthetic',
                confirmation: 'synthetic',
              );
              await SqliteAccountAppearance(
                database: db,
                session: session.decision.session!,
              ).write(
                AccountAppearance(
                  language: language,
                  theme: dark ? 'dark' : 'light',
                ),
              );
            });
            final prefs = AppPreferencesController(_Device());
            await prefs.ready;
            try {
              await t.pumpWidget(
                SirajApp(sessionController: session, preferences: prefs),
              );
              await t.pumpAndSettle();
              expect(t.takeException(), isNull);
              Future<void> tab(int index) async {
                if (width < 900) {
                  final nav = t.widget<NavigationBar>(
                    find.byType(NavigationBar),
                  );
                  final label =
                      nav.destinations[index] as NavigationDestination;
                  await t.tap(
                    find.descendant(
                      of: find.byType(NavigationBar),
                      matching: find.text(label.label),
                    ),
                  );
                } else {
                  final nav = t.widget<NavigationRail>(
                    find.byType(NavigationRail),
                  );
                  final label = (nav.destinations[index].label as Text).data!;
                  await t.tap(
                    find.descendant(
                      of: find.byType(NavigationRail),
                      matching: find.text(label),
                    ),
                  );
                }
                await t.pumpAndSettle();
                expect(t.takeException(), isNull);
                expect(
                  width < 900
                      ? t
                            .widget<NavigationBar>(find.byType(NavigationBar))
                            .selectedIndex
                      : t
                            .widget<NavigationRail>(find.byType(NavigationRail))
                            .selectedIndex,
                  index,
                );
              }

              await tab(1);
              await tab(2);
              await tab(3);
              await tab(0);
              await t.scrollUntilVisible(
                find.byKey(const Key('open-resource-status')),
                180,
                scrollable: find.byType(Scrollable).first,
              );
              await t.pumpAndSettle();
              await t.tap(find.byKey(const Key('open-resource-status')));
              await t.pumpAndSettle();
              expect(t.takeException(), isNull);
              await t.tap(find.byType(BackButton));
              await t.pumpAndSettle();
              await t.tap(find.byKey(const Key('open-settings')));
              await t.pumpAndSettle();
              expect(t.takeException(), isNull);
            } finally {
              await t.pumpWidget(const SizedBox());
              await t.pumpAndSettle();
              prefs.dispose();
              session.dispose();
              await runtime.close();
            }
          },
        );
      }
    }
  }
}
