import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show QueryRow;
import 'package:uuid/uuid.dart';

import '../../data/user_repository.dart';
import 'auth_models.dart';
import 'password_hasher.dart';
import 'session_guard.dart';
import 'session_marker_store.dart';

/// B-04 application service. UI integration comes later (B-06).
/// There is intentionally no production KDF default. Inject a PasswordHasher
/// ONLY after security review and device benchmarking approve its settings.
class AuthService {
  AuthService({
    required UserRepository users,
    required PasswordHasher passwordHasher,
    required SessionMarkerStore markerStore,
    SessionGuard? guard,
    Uuid? uuid,
    DateTime Function()? now,
    void Function(String step)? onDiagnosticStep,
  }) : _users = users,
       _passwordHasher = passwordHasher,
       _markerStore = markerStore,
       _guard = guard ?? SessionGuard(users),
       _uuid = uuid ?? Uuid(),
       _now = now ?? DateTime.now,
       _onDiagnosticStep = onDiagnosticStep;

  final UserRepository _users;
  final PasswordHasher _passwordHasher;
  final SessionMarkerStore _markerStore;
  final SessionGuard _guard;
  final Uuid _uuid;
  final DateTime Function() _now;
  final void Function(String step)? _onDiagnosticStep;
  void _checkpoint(String step) => _onDiagnosticStep?.call(step);
  AuthSession? _active;

  AuthSession? get activeSession => _active;

  String get _utc => _now().toUtc().toIso8601String();

  /// Match the normalization rule at signup and login.
  /// Full Unicode NFC normalization requires a dedicated reviewed policy.
  static String normalizeUsername(String username) =>
      username.trim().toLowerCase();

  Future<AuthSession> createAccount({
    required String username,
    required String password,
    required String confirmation,
  }) async {
    final normalized = normalizeUsername(username);
    if (normalized.isEmpty ||
        password.trim().isEmpty ||
        password != confirmation) {
      throw const AuthFailure(AuthFailureCode.invalidInput);
    }
    _checkpoint('signup.db_precheck_started');
    try {
      if (await _users.currentAccount() != null) {
        throw const AuthFailure(AuthFailureCode.accountAlreadyExists);
      }
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.databaseFailure);
    }

    _checkpoint('signup.kdf_started');
    final credential = await _passwordHasher.hashPassword(password);
    _checkpoint('signup.kdf_passed');
    final userId = _uuid.v4();
    final accountEpoch = _uuid.v4();
    _checkpoint('signup.db_create_started');
    try {
      await _users.create(
        userId: userId,
        accountEpoch: accountEpoch,
        usernameNormalized: normalized,
        usernameDisplay: username.trim(),
        passwordSalt: credential.salt,
        passwordHash: credential.hash,
        passwordParamsJson: credential.parametersJson,
        nowUtc: _utc,
      );
    } catch (_) {
      // The singleton constraint in SQLite, not this pre-check, is authoritative.
      try {
        if (await _users.currentAccount() != null) {
          throw const AuthFailure(AuthFailureCode.accountAlreadyExists);
        }
      } on AuthFailure {
        rethrow;
      } catch (_) {
        throw const AuthFailure(AuthFailureCode.databaseFailure);
      }
      throw const AuthFailure(AuthFailureCode.databaseFailure);
    }
    _checkpoint('signup.db_create_passed');
    return _createSession(userId: userId, accountEpoch: accountEpoch);
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    if (normalizeUsername(username).isEmpty || password.isEmpty) {
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }
    final row = await _accountRow();
    if (row == null ||
        row.read<String>('username_normalized') !=
            normalizeUsername(username)) {
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }

    bool valid;
    try {
      valid = await _passwordHasher.verifyPassword(
        password: password,
        salt: row.read<Uint8List>('password_salt'),
        expectedHash: row.read<Uint8List>('password_hash'),
        parametersJson: row.read<String>('password_params_json'),
      );
    } catch (_) {
      // Corrupted credentials must not become an authentication bypass.
      valid = false;
    }
    if (!valid) throw const AuthFailure(AuthFailureCode.invalidCredentials);
    return _createSession(
      userId: row.read<String>('user_id'),
      accountEpoch: row.read<String>('account_epoch'),
    );
  }

  /// Called on startup. A damaged/missing secure marker fails closed.
  /// Unexpected SQLite failures are surfaced separately, never treated as
  /// evidence that the user account doesn't exist.
  Future<AuthSession?> restoreSession() async {
    _active = null;
    String? raw;
    try {
      raw = await _markerStore.read();
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.secureStorageFailure);
    }
    if (raw == null) return null;
    final marker = PersistedSessionMarker.decode(raw);
    if (marker == null) {
      await _tryClearMarker();
      return null;
    }
    bool valid;
    try {
      valid = await _guard.isCurrent(marker.asSession());
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.databaseFailure);
    }
    if (!valid) {
      await _tryClearMarker();
      return null;
    }
    return _active = marker.asSession();
  }

  /// DB FIRST: any stale marker left behind is cryptographically invalid.
  Future<void> logout() async {
    final session = await _requireCurrent();
    int changed;
    try {
      changed = await _users.invalidateNonce(
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        nowUtc: _utc,
      );
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.databaseFailure);
    }
    if (changed != 1) {
      throw const AuthFailure(AuthFailureCode.sessionInvalid);
    }
    _active = null;
    // Cleanup is best-effort AFTER invalidation; no surviving marker can log in.
    await _tryClearMarker();
  }

  /// Called ONLY after Settings' explicit, confirmed destructive dialog.
  /// Deletion is committed in SQLite before cleaning encrypted marker.
  Future<void> deleteCurrentAccount({required bool confirmed}) async {
    if (!confirmed) {
      throw const AuthFailure(AuthFailureCode.confirmationRequired);
    }
    final session = await _requireCurrent();
    int changed;
    try {
      changed = await _users.deleteAccount(
        userId: session.userId,
        accountEpoch: session.accountEpoch,
      );
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.databaseFailure);
    }
    if (changed != 1) {
      throw const AuthFailure(AuthFailureCode.sessionInvalid);
    }
    _active = null;
    await _tryClearMarker();
  }

  Future<bool> checkSession(AuthSession session) => _guard.isCurrent(session);

  Future<AuthSession> _requireCurrent() async {
    final session = _active;
    if (session == null) {
      throw const AuthFailure(AuthFailureCode.sessionInvalid);
    }
    bool valid;
    try {
      valid = await _guard.isCurrent(session);
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.databaseFailure);
    }
    if (!valid) {
      _active = null;
      throw const AuthFailure(AuthFailureCode.sessionInvalid);
    }
    return session;
  }

  Future<QueryRow?> _accountRow() async {
    try {
      return await _users.currentAccount();
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.databaseFailure);
    }
  }

  Future<AuthSession> _createSession({
    required String userId,
    required String accountEpoch,
  }) async {
    _checkpoint('session.nonce_started');
    final secureRandom = Random.secure();
    final nonceBytes = Uint8List.fromList(
      List<int>.generate(32, (_) => secureRandom.nextInt(256)),
    );
    final nonce = base64UrlEncode(nonceBytes);
    final digest = await Sha256().hash(utf8.encode(nonce));
    _checkpoint('session.db_nonce_started');
    int changed;
    try {
      changed = await _users.setNonceHash(
        userId: userId,
        accountEpoch: accountEpoch,
        hash: Uint8List.fromList(digest.bytes),
        nowUtc: _utc,
      );
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.databaseFailure);
    }
    if (changed != 1) {
      throw const AuthFailure(AuthFailureCode.sessionInvalid);
    }
    _checkpoint('session.db_nonce_passed');
    final marker = PersistedSessionMarker(
      userId: userId,
      accountEpoch: accountEpoch,
      sessionNonce: nonce,
      issuedAt: _utc,
    );
    _checkpoint('session.secure_write_started');
    try {
      await _markerStore.write(marker);
    } catch (_) {
      // Cancel the nonce in DB even if secure storage may contain a partial write.
      try {
        await _users.invalidateNonce(
          userId: userId,
          accountEpoch: accountEpoch,
          nowUtc: _utc,
        );
      } catch (_) {
        // Fail closed. The caller must not be given a valid session.
      }
      _active = null;
      throw const AuthFailure(AuthFailureCode.secureStorageFailure);
    }
    _checkpoint('session.secure_write_passed');
    final session = marker.asSession();
    return _active = session;
  }

  Future<void> _tryClearMarker() async {
    try {
      await _markerStore.clear();
    } catch (_) {
      // The DB nonce/account row has already been invalidated, or restore
      // failed guard verification. Startup retries cleanup on a stale marker.
    }
  }
}
