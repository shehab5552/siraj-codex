import 'package:drift/drift.dart';

import 'app_database.dart';

/// Account persistence only. KDF, password policy and Keystore session marker
/// are responsibilities of B-04, not of this repository.
class UserRepository {
  final AppDatabase db;

  const UserRepository(this.db);

  Future<void> create({
    required String userId,
    required String accountEpoch,
    required String usernameNormalized,
    required String usernameDisplay,
    required Uint8List passwordSalt,
    required Uint8List passwordHash,
    required String passwordParamsJson,
    required String nowUtc,
    bool Function()? isRequestCurrent,
  }) async {
    if (userId.trim().isEmpty ||
        accountEpoch.trim().isEmpty ||
        usernameNormalized.trim().isEmpty ||
        usernameDisplay.trim().isEmpty ||
        passwordSalt.isEmpty ||
        passwordHash.isEmpty) {
      throw ArgumentError('Invalid account fields');
    }
    await db.transaction(() async {
      if (isRequestCurrent?.call() == false) {
        throw StateError('Request cancelled');
      }
      await db.customInsert(
        '''
      INSERT INTO user_profile
        (user_id, account_epoch, username_normalized, username_display,
         password_kdf, password_salt, password_hash, password_params_json,
         created_at, updated_at)
      VALUES (?, ?, ?, ?, 'PBKDF2-HMAC-SHA256', ?, ?, ?, ?, ?)
    ''',
        variables: [
          Variable.withString(userId),
          Variable.withString(accountEpoch),
          Variable.withString(usernameNormalized),
          Variable.withString(usernameDisplay),
          Variable.withBlob(passwordSalt),
          Variable.withBlob(passwordHash),
          Variable.withString(passwordParamsJson),
          Variable.withString(nowUtc),
          Variable.withString(nowUtc),
        ],
        updates: {db.userProfile},
      );
      if (isRequestCurrent?.call() == false) {
        throw StateError('Request cancelled');
      }
    });
  }

  /// Only one row can exist, enforced by singleton_slot UNIQUE CHECK = 1.
  Future<QueryRow?> currentAccount() =>
      db.customSelect('SELECT * FROM user_profile LIMIT 1').getSingleOrNull();

  /// Store the hash only; plaintext session markers belong in Keystore-backed
  /// secure storage (implemented in B-04).
  Future<int> setNonceHash({
    required String userId,
    required String accountEpoch,
    required Uint8List hash,
    required String nowUtc,
  }) {
    if (hash.isEmpty) throw ArgumentError('Empty nonce hash');
    return db.customUpdate(
      '''
      UPDATE user_profile SET active_session_nonce_hash = ?, updated_at = ?
      WHERE user_id = ? AND account_epoch = ?
    ''',
      variables: [
        Variable.withBlob(hash),
        Variable.withString(nowUtc),
        Variable.withString(userId),
        Variable.withString(accountEpoch),
      ],
      updates: {db.userProfile},
    );
  }

  /// Publish a session only if the credential operation still owns the exact
  /// account/previous nonce it authenticated. A newer login cannot be replaced.
  Future<int> compareAndSetNonceHash({
    required String userId,
    required String accountEpoch,
    required Uint8List? expectedNonceHash,
    required Uint8List hash,
    required String nowUtc,
    bool Function()? isRequestCurrent,
  }) => db.transaction(() async {
    if (isRequestCurrent?.call() == false) {
      throw StateError('Request cancelled');
    }
    final changed = await db.customUpdate(
      'UPDATE user_profile SET active_session_nonce_hash = ?, updated_at = ? '
      'WHERE user_id = ? AND account_epoch = ? AND active_session_nonce_hash IS ?',
      variables: [
        Variable.withBlob(hash),
        Variable.withString(nowUtc),
        Variable.withString(userId),
        Variable.withString(accountEpoch),
        Variable<Uint8List>(expectedNonceHash),
      ],
      updates: {db.userProfile},
    );
    if (isRequestCurrent?.call() == false) {
      throw StateError('Request cancelled');
    }
    return changed;
  });

  Future<int> invalidateNonce({
    required String userId,
    required String accountEpoch,
    required String nowUtc,
    Uint8List? expectedNonceHash,
  }) => db.customUpdate(
    '''
      UPDATE user_profile SET active_session_nonce_hash = NULL, updated_at = ?
      WHERE user_id = ? AND account_epoch = ?
      ${expectedNonceHash == null ? '' : 'AND active_session_nonce_hash = ?'}
    ''',
    variables: [
      Variable.withString(nowUtc),
      Variable.withString(userId),
      Variable.withString(accountEpoch),
      if (expectedNonceHash != null) Variable.withBlob(expectedNonceHash),
    ],
    updates: {db.userProfile},
  );

  /// Account-owned records cascade; installed_resource survives.
  /// Session marker invalidation outside SQLite is handled by B-04.
  Future<int> deleteAccount({
    required String userId,
    required String accountEpoch,
    Uint8List? expectedNonceHash,
  }) => db.transaction(
    () => db.customUpdate(
      '''
      DELETE FROM user_profile WHERE user_id = ? AND account_epoch = ?
      ${expectedNonceHash == null ? '' : 'AND active_session_nonce_hash = ?'}
    ''',
      variables: [
        Variable.withString(userId),
        Variable.withString(accountEpoch),
        if (expectedNonceHash != null) Variable.withBlob(expectedNonceHash),
      ],
      updates: {db.userProfile, db.conversation, db.message, db.appSetting},
    ),
  );
}
