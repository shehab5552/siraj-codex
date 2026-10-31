import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/app_preferences.dart';

class _Store implements AppPreferencesStore {
  AppPreferences value = const AppPreferences();
  bool fail = false;
  Completer<void>? barrier;
  @override
  Future<AppPreferences> read() async => value;
  @override
  Future<void> write(AppPreferences next) async {
    await barrier?.future;
    if (fail) throw StateError('disk');
    value = next;
  }
}

void main() {
  test('serialized updates retain all preferences across restart', () async {
    final store = _Store();
    final c = AppPreferencesController(store);
    await c.ready;
    store.barrier = Completer<void>();
    final first = c.setLocale(const Locale('en'));
    final second = c.setTheme(ThemeMode.dark);
    final third = c.completeOnboarding();
    store.barrier!.complete();
    await Future.wait([first, second, third]);
    c.dispose();
    final reopened = AppPreferencesController(store);
    await reopened.ready;
    expect(reopened.value.locale.languageCode, 'en');
    expect(reopened.value.themeMode, ThemeMode.dark);
    expect(reopened.value.onboardingComplete, isTrue);
    reopened.dispose();
  });
  test(
    'failed persistence does not claim saved selection and can recover',
    () async {
      final store = _Store()..fail = true;
      final c = AppPreferencesController(store);
      await c.ready;
      expect(await c.setTheme(ThemeMode.dark), isFalse);
      expect(c.value.themeMode, ThemeMode.system);
      expect(c.persistenceFailed, isTrue);
      store.fail = false;
      expect(await c.setTheme(ThemeMode.light), isTrue);
      expect(c.persistenceFailed, isFalse);
      c.dispose();
    },
  );
  test('corrupt preference payload is bounded and defaults safely', () {
    expect(
      AppPreferences.decode({
        'language': 'zz',
        'theme': 'injected',
        'onboarding': 1,
      }).locale.languageCode,
      'ar',
    );
    expect(
      AppPreferences.decode({'theme': 'dark', 'onboarding': true}).themeMode,
      ThemeMode.dark,
    );
    expect(AppPreferences.decode(null).onboardingComplete, isFalse);
  });
}
