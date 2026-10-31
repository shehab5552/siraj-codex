import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import '../../data/user_repository.dart';
import 'auth_models.dart';
import 'password_hasher.dart';

/// Checks the current DB row AND nonce hash each time. This is not merely
/// a check that an AuthSession object exists in RAM.
class SessionGuard {
  const SessionGuard(this._users);

  final UserRepository _users;
  static final _blocked = Expando<Set<String>>();
  // Retain only a digest in failure fences, never a deleted session's raw nonce.
  String _identity(AuthSession s) => base64Encode(
    const DartSha256()
        .hashSync(
          utf8.encode(
            '${s.userId}\u0000${s.accountEpoch}\u0000${s.sessionNonce}',
          ),
        )
        .bytes,
  );
  bool isBlocked(AuthSession session) =>
      _blocked[_users.db]?.contains(_identity(session)) == true;
  void block(AuthSession session) =>
      (_blocked[_users.db] ??= {}).add(_identity(session));

  Future<bool> isCurrent(AuthSession session) async {
    if (isBlocked(session)) return false;
    final valid = await matchesPersistedSessionForRevocation(session);
    return valid && !isBlocked(session);
  }

  /// Revocation retry only. Never use this to authorize UI/data access: a failed
  /// Logout may have fenced this still-persisted nonce in the running process.
  Future<bool> matchesPersistedSessionForRevocation(AuthSession session) async {
    if (session.userId.isEmpty ||
        session.accountEpoch.isEmpty ||
        session.sessionNonce.isEmpty) {
      return false;
    }

    final row = await _users.currentAccount();
    if (row == null ||
        row.read<String>('user_id') != session.userId ||
        row.read<String>('account_epoch') != session.accountEpoch) {
      return false;
    }
    final expected = row.read<Uint8List?>('active_session_nonce_hash');
    if (expected == null || expected.length != 32) return false;

    final digest = await Sha256().hash(utf8.encode(session.sessionNonce));
    return PasswordHasher.constantTimeEquals(digest.bytes, expected);
  }
}
