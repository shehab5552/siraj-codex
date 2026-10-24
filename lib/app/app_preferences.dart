import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Device appearance/onboarding only. Never stores credentials or authorizes
/// access to account data. Kept separate from account-owned SQLite settings.
class AppPreferences {
  const AppPreferences({
    this.locale = const Locale('ar'),
    this.themeMode = ThemeMode.system,
    this.onboardingComplete = false,
  });
  final Locale locale;
  final ThemeMode themeMode;
  final bool onboardingComplete;
  static AppPreferences decode(Object? raw) {
    final map = raw is Map ? raw : const {};
    return AppPreferences(
      locale: Locale(map['language'] == 'en' ? 'en' : 'ar'),
      themeMode: switch (map['theme']) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      onboardingComplete: map['onboarding'] == true,
    );
  }

  Map<String, Object> encode() => {
    'language': locale.languageCode,
    'theme': themeMode.name,
    'onboarding': onboardingComplete,
  };
  AppPreferences copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    bool? onboardingComplete,
  }) => AppPreferences(
    locale: locale ?? this.locale,
    themeMode: themeMode ?? this.themeMode,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
  );
}

abstract interface class AppPreferencesStore {
  Future<AppPreferences> read();
  Future<void> write(AppPreferences next);
}

class AndroidAppPreferencesStore implements AppPreferencesStore {
  const AndroidAppPreferencesStore();
  static const _channel = MethodChannel('siraj/appearance');
  @override
  Future<AppPreferences> read() async => AppPreferences.decode(
    await _channel
        .invokeMethod<Object?>('read')
        .timeout(const Duration(seconds: 5)),
  );
  @override
  Future<void> write(AppPreferences next) async {
    await _channel
        .invokeMethod<void>('write', next.encode())
        .timeout(const Duration(seconds: 5));
  }
}

class AppPreferencesController extends ChangeNotifier {
  AppPreferencesController(this._store) {
    ready = _load();
  }
  final AppPreferencesStore _store;
  late final Future<void> ready;
  AppPreferences _value = const AppPreferences();
  AppPreferences get value => _value;
  bool persistenceFailed = false;
  bool loaded = false;
  bool _disposed = false;
  Future<void> _tail = Future.value();
  Future<void> _load() async {
    try {
      _value = await _store.read();
    } catch (_) {
      persistenceFailed = true;
    }
    loaded = true;
    if (!_disposed) notifyListeners();
  }

  Future<bool> _update(AppPreferences Function(AppPreferences) change) {
    final result = Completer<bool>();
    _tail = _tail.then((_) async {
      await ready;
      if (_disposed) {
        result.complete(false);
        return;
      }
      final next = change(_value);
      try {
        await _store.write(next);
        _value = next;
        persistenceFailed = false;
        result.complete(true);
      } catch (_) {
        persistenceFailed = true;
        result.complete(false);
      }
      if (!_disposed) notifyListeners();
    });
    return result.future;
  }

  Future<bool> setLocale(Locale locale) => _update(
    (v) =>
        v.copyWith(locale: Locale(locale.languageCode == 'en' ? 'en' : 'ar')),
  );
  Future<bool> setTheme(ThemeMode theme) =>
      _update((v) => v.copyWith(themeMode: theme));
  Future<bool> completeOnboarding() =>
      _update((v) => v.copyWith(onboardingComplete: true));
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppPreferencesScope extends InheritedNotifier<AppPreferencesController> {
  const AppPreferencesScope({
    super.key,
    required AppPreferencesController controller,
    required super.child,
  }) : super(notifier: controller);
  static AppPreferencesController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppPreferencesScope>()
      ?.notifier;
}
