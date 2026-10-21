import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../data/user_repository.dart';
import 'auth_models.dart';
import 'password_hasher.dart';

/// Checks the current DB row AND nonce hash each time. This is not merely
/// a check that an AuthSession object exists in RAM.
class SessionGuard {
  const SessionGuard(this._users);

  final UserRepository _users;

  Future<bool> isCurrent(AuthSession session) async {
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
