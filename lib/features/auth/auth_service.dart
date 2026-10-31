import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show QueryRow;
import 'package:uuid/uuid.dart';

import '../../data/user_repository.dart';
import 'auth_models.dart';
import 'auth_operation_lane.dart';
import 'kdf_worker.dart';
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
       _onDiagnosticStep = onDiagnosticStep {
    _lane = AuthOperationLane.forDatabase(users.db);
  }

  final UserRepository _users;
  final PasswordHasher _passwordHasher;
  final SessionMarkerStore _markerStore;
  final SessionGuard _guard;
  final Uuid _uuid;
  final DateTime Function() _now;
  final void Function(String step)? _onDiagnosticStep;
  void _checkpoint(String step) {
    try {
      _onDiagnosticStep?.call(step);
    } catch (_) {
      /* Observation is not authorization. */
    }
  }

  late final AuthOperationLane _lane;
  AuthSession? _active;

  void cancelPendingAuthentication() => _lane.cancelPending();

  AuthSession? get activeSession =>
      _active == null || _guard.isBlocked(_active!) ? null : _active;

  String get _utc => _now().toUtc().toIso8601String();

  /// Match the normalization rule at signup and login.
  /// Full Unicode NFC normalization requires a dedicated reviewed policy.
  static String normalizeUsername(String username) =>
      username.trim().toLowerCase();

  Future<AuthSession> createAccount({
    required String username,
    required String password,
    required String confirmation,
  }) => _lane.run(
    (operation) => _createAccount(
      username: username,
      password: password,
      confirmation: confirmation,
      operation: operation,
    ),
  );

  Future<AuthSession> _createAccount({
    required String username,
    required String password,
    required String confirmation,
    required AuthOperation operation,
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
    final PasswordCredential credential;
    try {
      credential = await _passwordHasher.hashPassword(
        password,
        cancellation: operation.cancellation,
      );
    } on KdfFailure catch (error) {
      throw _kdfFailure(error);
    } on ArgumentError {
      throw const AuthFailure(AuthFailureCode.invalidInput);
    }
    operation.check();
    _checkpoint('signup.kdf_passed');
    final userId = _uuid.v4();
    final accountEpoch = _uuid.v4();
    _checkpoint('signup.db_create_started');
    operation.check();
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
        isRequestCurrent: () => operation.isCurrent,
      );
    } catch (_) {
      operation.check();
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
    try {
      operation.check();
      return await _createSession(
        userId: userId,
        accountEpoch: accountEpoch,
        expectedNonceHash: null,
        operation: operation,
      );
    } on AuthFailure catch (failure) {
      throw AuthFailure(failure.code, accountCreated: true);
    }
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) => _lane.run(
    (operation) =>
        _login(username: username, password: password, operation: operation),
  );

  Future<AuthSession> _login({
    required String username,
    required String password,
    required AuthOperation operation,
  }) async {
    if (normalizeUsername(username).isEmpty || password.isEmpty) {
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }
    final row = await _accountRow();
    if (row == null ||
        row.read<String>('password_kdf') != PasswordHasher.algorithm ||
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
        cancellation: operation.cancellation,
      );
    } on KdfFailure catch (error) {
      throw _kdfFailure(error);
    } catch (_) {
      // Corrupted credentials must not become an authentication bypass.
      valid = false;
    }
    operation.check();
    if (!valid) throw const AuthFailure(AuthFailureCode.invalidCredentials);
    return _createSession(
      userId: row.read<String>('user_id'),
      accountEpoch: row.read<String>('account_epoch'),
      expectedNonceHash: row.read<Uint8List?>('active_session_nonce_hash'),
      operation: operation,
    );
  }

  /// Called on startup. A damaged/missing secure marker fails closed.
  /// Unexpected SQLite failures are surfaced separately, never treated as
  /// evidence that the user account doesn't exist.
  Future<AuthSession?> restoreSession() => _lane.run(_restoreSession);

  Future<AuthSession?> _restoreSession(AuthOperation operation) async {
    _active = null;
    String? raw;
    try {
      raw = await _markerStore.read();
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.secureStorageFailure);
    }
    operation.check();
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
    operation.check();
    return _active = marker.asSession();
  }

  /// DB FIRST: any stale marker left behind is cryptographically invalid.
  Future<void> logout() {
    if (_active != null) _guard.block(_active!);
    return _lane.run((_) => _logout(), revoke: true);
  }

  Future<void> _logout() async {
    if (_active != null) _guard.block(_active!);
    final session = await _requireCurrent(forRevocation: true);
    int changed;
    try {
      changed = await _users.invalidateNonce(
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        nowUtc: _utc,
        expectedNonceHash: await _nonceHash(session.sessionNonce),
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
  Future<void> deleteCurrentAccount({required bool confirmed}) {
    if (!confirmed) {
      return Future.error(
        const AuthFailure(AuthFailureCode.confirmationRequired),
      );
    }
    if (_active != null) _guard.block(_active!);
    return _lane.run((_) => _deleteCurrentAccount(), revoke: true);
  }

  Future<void> _deleteCurrentAccount() async {
    if (_active != null) _guard.block(_active!);
    final session = await _requireCurrent(forRevocation: true);
    int changed;
    try {
      changed = await _users.deleteAccount(
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        expectedNonceHash: await _nonceHash(session.sessionNonce),
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

  Future<AuthSession> _requireCurrent({bool forRevocation = false}) async {
    final session = _active;
    if (session == null) {
      throw const AuthFailure(AuthFailureCode.sessionInvalid);
    }
    bool valid;
    try {
      valid = forRevocation
          ? await _guard.matchesPersistedSessionForRevocation(session)
          : await _guard.isCurrent(session);
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

  static AuthFailure _kdfFailure(KdfFailure failure) => AuthFailure(
    failure.code == KdfFailureCode.cancelled
        ? AuthFailureCode.operationCancelled
        : AuthFailureCode.kdfFailure,
  );

  static Future<Uint8List> _nonceHash(String nonce) async =>
      Uint8List.fromList((await Sha256().hash(utf8.encode(nonce))).bytes);

  Future<AuthSession> _createSession({
    required String userId,
    required String accountEpoch,
    required Uint8List? expectedNonceHash,
    required AuthOperation operation,
  }) async {
    operation.check();
    _checkpoint('session.nonce_started');
    final random = Random.secure();
    final nonce = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    final digest = await _nonceHash(nonce);
    final marker = PersistedSessionMarker(
      userId: userId,
      accountEpoch: accountEpoch,
      sessionNonce: nonce,
      issuedAt: _utc,
    );
    operation.check();
    _checkpoint('session.secure_write_started');
    try {
      // An unacknowledged/late secure write has no matching DB nonce yet.
      await _markerStore.write(marker);
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.secureStorageFailure);
    }
    operation.check();
    _checkpoint('session.secure_write_passed');
    int changed;
    _checkpoint('session.db_nonce_started');
    try {
      changed = await _users.compareAndSetNonceHash(
        userId: userId,
        accountEpoch: accountEpoch,
        expectedNonceHash: expectedNonceHash,
        hash: digest,
        nowUtc: _utc,
        isRequestCurrent: () => operation.isCurrent,
      );
    } catch (_) {
      operation.check();
      throw const AuthFailure(AuthFailureCode.databaseFailure);
    }
    if (changed != 1) throw const AuthFailure(AuthFailureCode.sessionInvalid);
    // Successful CAS is the durable commit boundary. A Cancel arriving during
    // its acknowledgement cannot undo a committed session. The queued
    // Logout/Delete barrier drains this operation and revokes this exact nonce.
    // No fallible asynchronous work occurs between CAS acknowledgement and
    // publishing RAM state; there is no best-effort rollback resurrection path.
    final session = marker.asSession();
    _active = session;
    _checkpoint('session.db_nonce_passed');
    return session;
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
