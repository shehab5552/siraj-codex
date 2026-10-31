import 'package:siraj/features/settings/account_appearance.dart';
import 'package:siraj/features/settings/settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/app_preferences.dart';
import 'package:siraj/app/app_session_controller.dart';
import 'package:siraj/app/siraj_app.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/database_runtime.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'support/auth_test_marker.dart';

class _Device implements AppPreferencesStore {
  AppPreferences value = const AppPreferences(onboardingComplete: true);
  @override
  Future<AppPreferences> read() async => value;
  @override
  Future<void> write(AppPreferences v) async {
    value = v;
  }
}

class _FailingAppearance implements AccountAppearanceStore {
  @override
  Future<AccountAppearance> read() async => const AccountAppearance();
  @override
  Future<void> write(AccountAppearance value) async =>
      throw StateError('isolated settings IO failure');
}

void main() {
  testWidgets(
    'settings persist account language in SQLite and preserve it for login',
    (t) async {
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
      });
      final device = _Device();
      final prefs = AppPreferencesController(device);
      await prefs.ready;
      try {
        await t.pumpWidget(
          SirajApp(sessionController: session, preferences: prefs),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('open-settings')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('settings-language-en')));
        await t.pumpAndSettle();
        final row = await db
            .customSelect(
              "SELECT value_json FROM app_setting WHERE setting_key='locale'",
            )
            .getSingleOrNull();
        expect(row?.read<String>('value_json'), '"en"');
        expect(device.value.locale.languageCode, 'ar');
        await t.scrollUntilVisible(
          find.byKey(const Key('settings-logout')),
          180,
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('settings-logout')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('confirm-account-action')));
        await t.runAsync(() async {
          for (var i = 0; i < 100 && session.busy; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });
        await t.pumpAndSettle();
        expect(find.text('Log in'), findsWidgets);
        expect(prefs.value.locale.languageCode, 'en');
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        session.dispose();
        prefs.dispose();
        await runtime.close();
      }
    },
  );
  testWidgets(
    'failed preference save leaves the selector on the persisted value',
    (t) async {
      final runtime = DatabaseRuntime(
        createDatabase: () => AppDatabase.forTesting(NativeDatabase.memory()),
      );
      final session = AppSessionController(
        runtime: runtime,
        markerStore: ControlledMarker(),
      );
      final prefs = AppPreferencesController(_Device());
      await prefs.ready;
      await prefs.bindAccount(identity: Object(), store: _FailingAppearance());
      try {
        await t.pumpWidget(
          AppPreferencesScope(
            controller: prefs,
            child: MaterialApp(
              home: SettingsPage(session: session, onOpenResources: () {}),
            ),
          ),
        );
        await t.tap(find.byKey(const Key('settings-theme-dark')));
        await t.pumpAndSettle();
        expect(prefs.persistenceFailed, isTrue);
        expect(prefs.value.themeMode, ThemeMode.system);
      } finally {
        await t.pumpWidget(const SizedBox());
        prefs.dispose();
        session.dispose();
        await runtime.close();
      }
    },
  );
}
