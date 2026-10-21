import 'package:drift/drift.dart';

import 'app_database.dart';

/// Account-scoped settings; epoch prevents stale-session writes.
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
}
