import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../../data/app_database.dart';
import '../../data/settings_repository.dart';
import '../../data/user_repository.dart';
import '../auth/auth_models.dart';
import '../auth/session_guard.dart';

class AccountAppearance {
  const AccountAppearance({this.language = 'ar', this.theme = 'system'});
  final String language, theme;
}

abstract interface class AccountAppearanceStore {
  Future<AccountAppearance> read();
  Future<void> write(AccountAppearance appearance);
}

/// Only non-secret enum preferences are read before login; no username, account
/// identifier, messages, password material or session authorization is exposed.
class ReadOnlyCurrentAccountAppearance implements AccountAppearanceStore {
  const ReadOnlyCurrentAccountAppearance(this.database);
  final AppDatabase database;
  @override
  Future<AccountAppearance> read() async {
    final value = await SettingsRepository(database).readAppearance();
    return value == null
        ? const AccountAppearance()
        : AccountAppearance(language: value.$1, theme: value.$2);
  }

  @override
  Future<void> write(AccountAppearance appearance) async =>
      throw const AuthFailure(AuthFailureCode.sessionInvalid);
}

class SqliteAccountAppearance implements AccountAppearanceStore {
  const SqliteAccountAppearance({
    required this.database,
    required this.session,
  });
  final AppDatabase database;
  final AuthSession session;
  SessionGuard get _guard => SessionGuard(UserRepository(database));
  Future<Uint8List> _nonce() async => Uint8List.fromList(
    (await Sha256().hash(utf8.encode(session.sessionNonce))).bytes,
  );
  @override
  Future<AccountAppearance> read() async {
    if (!await _guard.isCurrent(session)) {
      throw const AuthFailure(AuthFailureCode.sessionInvalid);
    }
    final value = await SettingsRepository(database).readAppearance(
      userId: session.userId,
      accountEpoch: session.accountEpoch,
      nonceHash: await _nonce(),
    );
    if (value == null || !await _guard.isCurrent(session)) {
      throw const AuthFailure(AuthFailureCode.sessionInvalid);
    }
    return AccountAppearance(language: value.$1, theme: value.$2);
  }

  @override
  Future<void> write(AccountAppearance appearance) async {
    if (!await _guard.isCurrent(session)) {
      throw const AuthFailure(AuthFailureCode.sessionInvalid);
    }
    final changed = await SettingsRepository(database).writeAppearanceSession(
      userId: session.userId,
      accountEpoch: session.accountEpoch,
      nonceHash: await _nonce(),
      language: appearance.language,
      theme: appearance.theme,
      nowUtc: DateTime.now().toUtc().toIso8601String(),
      isRequestCurrent: () => !_guard.isBlocked(session),
    );
    if (changed != 1) throw const AuthFailure(AuthFailureCode.sessionInvalid);
  }
}
