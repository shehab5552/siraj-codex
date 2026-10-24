import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:siraj/data/settings_repository.dart';
import 'package:siraj/features/auth/session_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/app_preferences.dart';
import 'package:siraj/features/settings/account_appearance.dart';
import 'support/chat_fixture.dart';

class _Device implements AppPreferencesStore {
  AppPreferences value = const AppPreferences(onboardingComplete: true);
  @override
  Future<AppPreferences> read() async => value;
  @override
  Future<void> write(AppPreferences next) async {
    value = next;
  }
}

void main() {
  late ChatFixture f;
  setUp(() async {
    f = ChatFixture();
    await f.initialize();
  });
  tearDown(() async {
    await f.close();
  });
  test(
    'account locale and theme survive restart in guarded SQLite, not device appearance',
    () async {
      final device = _Device();
      final c = AppPreferencesController(device);
      await c.ready;
      await c.bindAccount(
        identity: Object(),
        store: SqliteAccountAppearance(database: f.db, session: f.session),
      );
      expect(await c.setLocale(const Locale('en')), isTrue);
      expect(await c.setTheme(ThemeMode.dark), isTrue);
      expect(device.value.locale.languageCode, 'ar');
      expect(device.value.themeMode, ThemeMode.system);
      c.dispose();
      final reopened = AppPreferencesController(device);
      await reopened.ready;
      await reopened.bindAccount(
        identity: Object(),
        store: SqliteAccountAppearance(database: f.db, session: f.session),
      );
      expect(reopened.value.locale.languageCode, 'en');
      expect(reopened.value.themeMode, ThemeMode.dark);
      expect(
        (await f.db.customSelect('SELECT * FROM app_setting').get()).length,
        2,
      );
      reopened.dispose();
    },
  );
  test(
    'revoked nonce cannot update settings even with the same account epoch',
    () async {
      final store = SqliteAccountAppearance(database: f.db, session: f.session);
      await store.write(const AccountAppearance(language: 'en', theme: 'dark'));
      await f.logout();
      await expectLater(
        store.write(const AccountAppearance(language: 'ar', theme: 'light')),
        throwsA(anything),
      );
      final signedOut = await ReadOnlyCurrentAccountAppearance(f.db).read();
      expect(signedOut.language, 'en');
      expect(signedOut.theme, 'dark');
    },
  );
  test(
    'account deletion clears appearance while onboarding remains device scoped',
    () async {
      final device = _Device();
      final c = AppPreferencesController(device);
      await c.ready;
      await c.bindAccount(
        identity: Object(),
        store: SqliteAccountAppearance(database: f.db, session: f.session),
      );
      await c.setLocale(const Locale('en'));
      await c.setTheme(ThemeMode.dark);
      await f.users.deleteAccount(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
      );
      await c.bindAccount(identity: Object(), store: null);
      expect(c.value.locale.languageCode, 'ar');
      expect(c.value.themeMode, ThemeMode.system);
      expect(c.value.onboardingComplete, isTrue);
      expect(
        await f.db.customSelect('SELECT * FROM app_setting').get(),
        isEmpty,
      );
      c.dispose();
    },
  );
  test('in-flight revocation rolls back both account setting rows and profile locale',()async{
    final guard=SessionGuard(f.users);var scheduled=false;
    final hash=Uint8List.fromList((await Sha256().hash(utf8.encode(f.session.sessionNonce))).bytes);
    await expectLater(SettingsRepository(f.db).writeAppearanceSession(userId:f.session.userId,accountEpoch:f.session.accountEpoch,nonceHash:hash,language:'en',theme:'dark',nowUtc:DateTime.now().toUtc().toIso8601String(),isRequestCurrent:(){
      if(!scheduled){scheduled=true;scheduleMicrotask(()=>guard.block(f.session));}
      return !guard.isBlocked(f.session);
    }),throwsStateError);
    expect(await f.db.customSelect('SELECT * FROM app_setting').get(),isEmpty);
    expect((await f.users.currentAccount())!.read<String>('locale'),'ar');
  });

}
