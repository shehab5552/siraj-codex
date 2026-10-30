import 'dart:convert';
import 'package:drift/drift.dart';

import 'app_database.dart';

/// Account-scoped settings. UI uses writeAppearanceSession for nonce/fence
/// protection; the low-level generic helpers alone check only account epoch.
class SettingsRepository {
  final AppDatabase db;
  const SettingsRepository(this.db);

  Future<String?> read({
    required String userId,
    required String accountEpoch,
    required String key,
  }) async {
    final row = await db
        .customSelect(
          '''
      SELECT s.value_json FROM app_setting s
      JOIN user_profile u ON u.user_id = s.user_id
      WHERE s.user_id = ? AND u.account_epoch = ? AND s.setting_key = ?
    ''',
          variables: [
            Variable.withString(userId),
            Variable.withString(accountEpoch),
            Variable.withString(key),
          ],
        )
        .getSingleOrNull();
    return row?.read<String>('value_json');
  }

  /// Returns affected row count (0 if account/epoch no longer matches).
  Future<int> write({
    required String userId,
    required String accountEpoch,
    required String key,
    required String valueJson,
    required String nowUtc,
  }) {
    if (key.trim().isEmpty) throw ArgumentError('Empty setting key');
    return db.customUpdate(
      '''
      INSERT INTO app_setting (user_id, setting_key, value_json, updated_at)
      SELECT user_id, ?, ?, ? FROM user_profile
      WHERE user_id = ? AND account_epoch = ?
      ON CONFLICT(user_id, setting_key) DO UPDATE SET
        value_json = excluded.value_json, updated_at = excluded.updated_at
    ''',
      variables: [
        Variable.withString(key),
        Variable.withString(valueJson),
        Variable.withString(nowUtc),
        Variable.withString(userId),
        Variable.withString(accountEpoch),
      ],
    );
  }

  Future<int> remove({
    required String userId,
    required String accountEpoch,
    required String key,
  }) => db.customUpdate(
    '''
      DELETE FROM app_setting WHERE user_id = ? AND setting_key = ?
      AND EXISTS(SELECT 1 FROM user_profile u
        WHERE u.user_id = app_setting.user_id AND u.account_epoch = ?)
    ''',
    variables: [
      Variable.withString(userId),
      Variable.withString(key),
      Variable.withString(accountEpoch),
    ],
  );
  Future<(String, String)?> readAppearance({
    String? userId,
    String? accountEpoch,
    Uint8List? nonceHash,
  }) async {
    final scoped = userId != null;
    if (scoped && (accountEpoch == null || nonceHash == null)) {
      throw ArgumentError('Incomplete settings scope');
    }
    final row = await db.customSelect(
      """
      SELECT u.locale,(SELECT s.value_json FROM app_setting s WHERE s.user_id=u.user_id AND s.setting_key='theme') AS theme_json
      FROM user_profile u WHERE u.singleton_slot=1
      ${scoped ? 'AND u.user_id=? AND u.account_epoch=? AND u.active_session_nonce_hash=?' : ''}
    """,
      variables: scoped
          ? [
              Variable.withString(userId),
              Variable.withString(accountEpoch!),
              Variable.withBlob(nonceHash!),
            ]
          : [],
    ).getSingleOrNull();
    if (row == null) return null;
    final language = row.read<String>('locale') == 'en' ? 'en' : 'ar';
    final raw = row.read<String?>('theme_json');
    String theme = 'system';
    if (raw != null && raw.length <= 64) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded == 'dark' || decoded == 'light') theme = decoded as String;
      } on FormatException {
        /* Corrupt non-secret setting defaults safely. */
      }
    }
    return (language, theme);
  }

  /// Both account preferences commit together under the current nonce. The
  /// synchronous fence catches Logout/Delete requested during the transaction.
  Future<int> writeAppearanceSession({
    required String userId,
    required String accountEpoch,
    required Uint8List nonceHash,
    required String language,
    required String theme,
    required String nowUtc,
    required bool Function() isRequestCurrent,
  }) async {
    if (!const ['ar', 'en'].contains(language) ||
        !const ['system', 'light', 'dark'].contains(theme)) {
      throw ArgumentError('Invalid appearance');
    }
    return db.transaction(() async {
      if (!isRequestCurrent()) throw StateError('Settings session expired');
      final changed = await db.customUpdate(
        """
        UPDATE user_profile SET locale=?,updated_at=? WHERE user_id=? AND account_epoch=? AND active_session_nonce_hash=?
      """,
        variables: [
          Variable.withString(language),
          Variable.withString(nowUtc),
          Variable.withString(userId),
          Variable.withString(accountEpoch),
          Variable.withBlob(nonceHash),
        ],
        updates: {db.userProfile},
      );
      if (changed != 1) return 0;
      for (final entry in {'locale': language, 'theme': theme}.entries) {
        await write(
          userId: userId,
          accountEpoch: accountEpoch,
          key: entry.key,
          valueJson: jsonEncode(entry.value),
          nowUtc: nowUtc,
        );
      }
      if (!isRequestCurrent()) throw StateError('Settings session expired');
      return 1;
    });
  }
}
