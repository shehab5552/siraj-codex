import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import 'auth_models.dart';

/// SIRAJ P0: only the encrypted session marker is stored outside SQLite.
/// The Android key is protected by AndroidKeyStore; no plaintext preferences.
/// DB holds only the session nonce hash, as required by the account contract.
abstract interface class SessionMarkerStore {
  Future<String?> read();
  Future<void> write(PersistedSessionMarker marker);
  Future<void> clear();
}

class KeystoreSessionMarkerStore implements SessionMarkerStore {
  const KeystoreSessionMarkerStore() : _scope = 'production';

  /// Exclusive disposable namespace for physical Android integration tests.
  @visibleForTesting
  const KeystoreSessionMarkerStore.forTesting() : _scope = 'b04_test';

  final String _scope;
  static const MethodChannel _channel = MethodChannel('siraj/auth_keystore_v1');
  static const Duration _deadline = Duration(seconds: 15);

  @override
  Future<String?> read() => _channel
      .invokeMethod<String>('read', <String, String>{'scope': _scope})
      .timeout(_deadline);

  @override
  Future<void> write(PersistedSessionMarker marker) async {
    await _channel
        .invokeMethod<void>('write', <String, String>{
          'scope': _scope,
          'marker': marker.encode(),
        })
        .timeout(_deadline);
  }

  @override
  Future<void> clear() async {
    await _channel
        .invokeMethod<void>('clear', <String, String>{'scope': _scope})
        .timeout(_deadline);
  }
}
