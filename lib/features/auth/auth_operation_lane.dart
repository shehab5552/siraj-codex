import 'dart:async';

import 'auth_models.dart';
import 'kdf_worker.dart';

/// One process-local mutation lane for an opened account database. Duplicate
/// credential requests fail fast; Logout/Delete cancel and drain earlier work.
class AuthOperationLane {
  static final _databases = Expando<AuthOperationLane>();
  static AuthOperationLane forDatabase(Object database) =>
      _databases[database] ??= AuthOperationLane();
  Future<void> _tail = Future.value();
  var _pending = 0;
  var _generation = 0;
  var _revoking = false;
  KdfCancellation? _cancellation;

  /// Startup reads and stale-marker cleanup share the mutation order. They may
  /// queue behind existing work, but cannot erase a subsequently issued marker.
  Future<T> read<T>(Future<T> Function() action) {
    final previous = _tail;
    final settled = Completer<void>();
    _tail = settled.future;
    ++_pending;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        --_pending;
        settled.complete();
      }
    }();
  }

  void cancelPending() {
    ++_generation;
    _cancellation?.cancel();
  }

  Future<T> run<T>(
    Future<T> Function(AuthOperation operation) action, {
    bool revoke = false,
  }) {
    if (_revoking || (_pending > 0 && !revoke)) {
      return Future.error(
        const AuthFailure(AuthFailureCode.operationInProgress),
      );
    }
    if (revoke) {
      _revoking = true;
      cancelPending();
    }
    final previous = _tail;
    final settled = Completer<void>();
    _tail = settled.future;
    ++_pending;
    final operation = AuthOperation(this, _generation);
    return () async {
      await previous;
      _cancellation = operation.cancellation;
      try {
        operation.check();
        return await action(operation);
      } finally {
        if (identical(_cancellation, operation.cancellation)) {
          _cancellation = null;
        }
        operation.cancellation.cancel();
        --_pending;
        if (revoke) _revoking = false;
        settled.complete();
      }
    }();
  }
}

class AuthOperation {
  AuthOperation(this._lane, this._generation);
  final AuthOperationLane _lane;
  final int _generation;
  final cancellation = KdfCancellation();
  bool get isCurrent =>
      _generation == _lane._generation && !cancellation.isCancelled;
  void check() {
    if (_generation != _lane._generation || cancellation.isCancelled) {
      throw const AuthFailure(AuthFailureCode.operationCancelled);
    }
  }
}
