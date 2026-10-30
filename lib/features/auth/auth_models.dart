import 'dart:convert';

/// Runtime-only identity. The nonce MUST NOT be logged or persisted in SQLite.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.accountEpoch,
    required this.sessionNonce,
  });

  final String userId;
  final String accountEpoch;
  final String sessionNonce;
}

/// Sensitive marker: only the encrypted secure-storage implementation persists it.
class PersistedSessionMarker {
  const PersistedSessionMarker({
    required this.userId,
    required this.accountEpoch,
    required this.sessionNonce,
    required this.issuedAt,
  });

  final String userId;
  final String accountEpoch;
  final String sessionNonce;
  final String issuedAt;

  AuthSession asSession() => AuthSession(
    userId: userId,
    accountEpoch: accountEpoch,
    sessionNonce: sessionNonce,
  );

  String encode() => jsonEncode({
    'user_id': userId,
    'account_epoch': accountEpoch,
    'session_nonce': sessionNonce,
    'issued_at': issuedAt,
  });

  static PersistedSessionMarker? decode(String raw) {
    if (raw.length > 4096) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      final userId = data['user_id'];
      final accountEpoch = data['account_epoch'];
      final sessionNonce = data['session_nonce'];
      final issuedAt = data['issued_at'];
      if (userId is! String ||
          accountEpoch is! String ||
          sessionNonce is! String ||
          issuedAt is! String ||
          userId.isEmpty ||
          accountEpoch.isEmpty ||
          sessionNonce.isEmpty ||
          DateTime.tryParse(issuedAt) == null) {
        return null;
      }
      return PersistedSessionMarker(
        userId: userId,
        accountEpoch: accountEpoch,
        sessionNonce: sessionNonce,
        issuedAt: issuedAt,
      );
    } on FormatException {
      return null;
    }
  }
}

enum AuthFailureCode {
  invalidInput,
  accountAlreadyExists,
  invalidCredentials,
  sessionInvalid,
  confirmationRequired,
  databaseFailure,
  secureStorageFailure,
  operationInProgress,
  operationCancelled,
  kdfFailure,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, {this.accountCreated = false});
  final AuthFailureCode code;
  final bool accountCreated;

  @override
  String toString() => 'AuthFailure(${code.name})';
}
