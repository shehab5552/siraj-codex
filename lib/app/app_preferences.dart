import '../features/settings/account_appearance.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Presentation preferences. Account appearance is persisted in guarded SQLite;
/// only onboarding is device-scoped. Preferences never authorize account access.
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
  Future<AppPreferences> read() async {
    final raw = await _channel
        .invokeMethod<Object?>('read')
        .timeout(const Duration(seconds: 5));
    // Ignore legacy device-scoped account preferences; SQLite owns them.
    return AppPreferences(
      onboardingComplete: raw is Map && raw['onboarding'] == true,
    );
  }

  @override
  Future<void> write(AppPreferences next) async {
    await _channel
        .invokeMethod<void>('write', {'onboarding': next.onboardingComplete})
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
  AccountAppearanceStore? _accountStore;
  Object? _accountIdentity;
  bool _hasBinding = false;
  int _scopeVersion = 0;
  bool accountLoading = false;
  Future<void> bindAccount({
    required Object identity,
    required AccountAppearanceStore? store,
  }) {
    if (_disposed || (_hasBinding && _accountIdentity == identity)) {
      return Future.value();
    }
    _hasBinding = true;
    _accountIdentity = identity;
    _accountStore = store;
    final version = ++_scopeVersion;
    accountLoading = true;
    final done = Completer<void>();
    _tail = _tail.then((_) async {
      await ready;
      try {
        final value = await store?.read() ?? const AccountAppearance();
        if (!_disposed && version == _scopeVersion) {
          final decoded = AppPreferences.decode({
            'language': value.language,
            'theme': value.theme,
          });
          _value = _value.copyWith(
            locale: decoded.locale,
            themeMode: decoded.themeMode,
          );
          persistenceFailed = false;
        }
      } catch (_) {
        if (!_disposed && version == _scopeVersion) {
          _value = _value.copyWith(
            locale: const Locale('ar'),
            themeMode: ThemeMode.system,
          );
          persistenceFailed = true;
        }
      } finally {
        if (!_disposed && version == _scopeVersion) {
          accountLoading = false;
          notifyListeners();
        }
        done.complete();
      }
    });
    return done.future;
  }

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
    final version = _scopeVersion;
    _tail = _tail.then((_) async {
      await ready;
      if (_disposed || version != _scopeVersion) {
        result.complete(false);
        return;
      }
      final next = change(_value);
      try {
        final appearanceChanged =
            next.locale != _value.locale || next.themeMode != _value.themeMode;
        final onboardingChanged =
            next.onboardingComplete != _value.onboardingComplete;
        if (appearanceChanged && _accountStore != null) {
          await _accountStore!.write(
            AccountAppearance(
              language: next.locale.languageCode,
              theme: next.themeMode.name,
            ),
          );
        } else if (appearanceChanged || onboardingChanged) {
          await _store.write(next);
        }
        if (_disposed || version != _scopeVersion) {
          result.complete(false);
          return;
        }
        _value = next;
        persistenceFailed = false;
        result.complete(true);
      } catch (_) {
        if (!_disposed && version == _scopeVersion) persistenceFailed = true;
        result.complete(false);
      }
      if (!_disposed && version == _scopeVersion) notifyListeners();
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
    _scopeVersion++;
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
