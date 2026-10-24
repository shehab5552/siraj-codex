import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/database_runtime.dart';
import '../data/user_repository.dart';
import '../features/auth/auth_models.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/kdf_worker.dart';
import '../features/auth/password_hasher.dart';
import '../features/auth/session_marker_store.dart';
import '../features/auth/startup_session_resolver.dart';

/// Composition and route state only. Authentication, nonce CAS and cross-store
/// ordering remain exclusively in AuthService and its database-wide lane.
class AppSessionController extends ChangeNotifier {
  AppSessionController({
    required this.runtime,
    required SessionMarkerStore markerStore,
    PasswordHasher? passwordHasher,
  }) : _marker = markerStore,
       _hasApprovedProfile = passwordHasher != null {
    _auth = AuthService(
      users: UserRepository(runtime.database),
      markerStore: markerStore,
      passwordHasher:
          passwordHasher ??
          PasswordHasher(
            iterations: PasswordHasher.candidateIterations,
            worker: const _DisabledKdf(),
          ),
    );
  }
  final DatabaseRuntime runtime;
  final SessionMarkerStore _marker;
  final bool _hasApprovedProfile;
  late final AuthService _auth;
  StartupDecision _decision = const StartupDecision(
    StartupStatus.loginRequired,
  );
  StartupDecision get decision => _decision;
  AuthSession? _navigationSession;
  Object _navigationIdentity = Object();

  /// Opaque route key: raw session nonces must not appear in widget diagnostics.
  /// Restoring the same nonce keeps the existing private Navigator and draft.
  Object get navigationIdentity {
    final next = _decision.session;
    final previous = _navigationSession;
    if (next?.userId != previous?.userId ||
        next?.accountEpoch != previous?.accountEpoch ||
        next?.sessionNonce != previous?.sessionNonce) {
      _navigationSession = next;
      _navigationIdentity = Object();
    }
    return _navigationIdentity;
  }

  bool busy = false;
  bool initialized = false;
  bool revocationFailed = false;
  bool _disposed = false;
  int _version = 0;
  Future<void>? _initialization;
  bool get canAuthenticate => _hasApprovedProfile && !busy;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initialization ??= refresh();
  Future<void> refresh() async {
    final version = ++_version;
    final decision = await StartupSessionResolver(
      users: UserRepository(runtime.database),
      markerStore: _marker,
    ).resolve();
    if (_disposed || version != _version) return;
    if (decision.status == StartupStatus.authenticated) {
      try {
        final restored = await _auth.restoreSession();
        if (_disposed || version != _version) return;
        _decision = restored == null
            ? const StartupDecision(StartupStatus.loginRequired)
            : StartupDecision(StartupStatus.authenticated, session: restored);
      } catch (_) {
        _decision = const StartupDecision(
          StartupStatus.secureStorageUnavailable,
        );
      }
    } else {
      _decision = decision;
    }
    initialized = true;
    _notify();
  }

  Future<void> _authenticate(Future<AuthSession> Function() action) async {
    if (!canAuthenticate) {
      throw const AuthFailure(AuthFailureCode.operationInProgress);
    }
    final version = ++_version;
    busy = true;
    _notify();
    try {
      final session = await action();
      if (!_disposed && version == _version) {
        _decision = StartupDecision(
          StartupStatus.authenticated,
          session: session,
        );
        revocationFailed = false;
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> createAccount({
    required String username,
    required String password,
    required String confirmation,
  }) => _authenticate(
    () => _auth.createAccount(
      username: username,
      password: password,
      confirmation: confirmation,
    ),
  );
  Future<void> login({required String username, required String password}) =>
      _authenticate(() => _auth.login(username: username, password: password));
  void cancelPendingAuthentication() => _auth.cancelPendingAuthentication();
  Future<bool> checkSession(AuthSession session) => _auth.checkSession(session);
  Future<void> logout() => _revoke(delete: false);
  Future<void> deleteAccount({required bool confirmed}) {
    if (!confirmed) {
      return Future.error(
        const AuthFailure(AuthFailureCode.confirmationRequired),
      );
    }
    return _revoke(delete: true);
  }

  Future<void> _revoke({required bool delete}) async {
    ++_version;
    // Remove all account routes immediately. AuthService synchronously fences
    // the nonce before its first await; a failing revocation stays closed.
    final operation = delete
        ? _auth.deleteCurrentAccount(confirmed: true)
        : _auth.logout();
    _decision = const StartupDecision(StartupStatus.loginRequired);
    busy = true;
    _notify();
    try {
      await operation;
      _decision = StartupDecision(
        delete ? StartupStatus.accountRequired : StartupStatus.loginRequired,
      );
      revocationFailed = false;
    } catch (_) {
      revocationFailed = true;
      rethrow;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_version;
    _auth.cancelPendingAuthentication();
    super.dispose();
  }
}

class _DisabledKdf implements Pbkdf2Worker {
  const _DisabledKdf();
  @override
  Future<Uint8List> derive({
    required String password,
    required Uint8List salt,
    required int iterations,
    KdfCancellation? cancellation,
  }) => Future.error(const KdfFailure(KdfFailureCode.failed));
}
