import '../../data/user_repository.dart';
import 'auth_models.dart';
import 'auth_operation_lane.dart';
import 'session_guard.dart';
import 'session_marker_store.dart';

enum StartupStatus {
  accountRequired,
  loginRequired,
  authenticated,
  databaseUnavailable,
  secureStorageUnavailable,
}

/// No password hashing, account creation or automatic login occurs here.
/// Only a nonce already registered in SQLite and protected by Android Keystore
/// can lead to [StartupStatus.authenticated].
class StartupDecision {
  const StartupDecision(this.status, {this.session});

  final StartupStatus status;
  final AuthSession? session;
}

class StartupSessionResolver {
  const StartupSessionResolver({
    required UserRepository users,
    required SessionMarkerStore markerStore,
  }) : _users = users,
       _markerStore = markerStore;

  final UserRepository _users;
  final SessionMarkerStore _markerStore;

  Future<StartupDecision> resolve() =>
      AuthOperationLane.forDatabase(_users.db).read(_resolve);

  Future<StartupDecision> _resolve() async {
    try {
      final account = await _users.currentAccount();
      if (account == null) {
        // An old marker cannot create an account. Cleanup deletes ciphertext
        // without reading/decrypting it or prompting for a Keystore key.
        await _clearStaleMarker();
        return const StartupDecision(StartupStatus.accountRequired);
      }
    } catch (_) {
      return const StartupDecision(StartupStatus.databaseUnavailable);
    }

    final String? raw;
    try {
      raw = await _markerStore.read();
    } catch (_) {
      return const StartupDecision(StartupStatus.secureStorageUnavailable);
    }

    if (raw == null) {
      return const StartupDecision(StartupStatus.loginRequired);
    }
    final marker = PersistedSessionMarker.decode(raw);
    if (marker == null) {
      await _clearStaleMarker();
      return const StartupDecision(StartupStatus.loginRequired);
    }
    final session = marker.asSession();
    try {
      if (!await SessionGuard(_users).isCurrent(session)) {
        await _clearStaleMarker();
        return const StartupDecision(StartupStatus.loginRequired);
      }
    } catch (_) {
      return const StartupDecision(StartupStatus.databaseUnavailable);
    }
    return StartupDecision(StartupStatus.authenticated, session: session);
  }

  Future<void> _clearStaleMarker() async {
    try {
      await _markerStore.clear().timeout(const Duration(seconds: 2));
    } catch (_) {
      /* Cleanup never grants a session; retry next startup. */
    }
  }
}
