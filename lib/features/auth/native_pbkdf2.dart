import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'kdf_worker.dart';

/// Android's PBKDF2WithHmacSHA256 runs off the platform/UI thread.
/// Cancellation ends the logical request immediately; the lane remains owned
/// until native work drains. Neither retry nor timeout can queue another KDF.
class NativePbkdf2 implements Pbkdf2Worker {
  NativePbkdf2({this.deadline = const Duration(seconds: 60)});
  static const _channel = MethodChannel('siraj/password_kdf');
  final Duration deadline;
  bool _busy = false;

  @override
  Future<Uint8List> derive({
    required String password,
    required Uint8List salt,
    required int iterations,
    KdfCancellation? cancellation,
  }) async {
    if (cancellation?.isCancelled == true) {
      throw const KdfFailure(KdfFailureCode.cancelled);
    }
    if (_busy) throw const KdfFailure(KdfFailureCode.busy);
    if (iterations < 1 ||
        iterations > 5000000 ||
        salt.isEmpty ||
        salt.length > 256 ||
        password.isEmpty ||
        utf8.encode(password).length > 1024 ||
        deadline <= Duration.zero) {
      throw ArgumentError('Invalid PBKDF2 parameters');
    }
    _busy = true;
    var abandoned = false;
    final native = _channel
        .invokeMethod<Uint8List>('derive', {
          'password': password,
          'salt': Uint8List.fromList(salt),
          'iterations': iterations,
        })
        .then((bytes) {
          if (bytes == null || bytes.length != 32) {
            throw const KdfFailure(KdfFailureCode.failed);
          }
          // Android's codec may return a read-only view. Own a mutable copy
          // for verifier cleanup; never mutate a foreign platform buffer.
          final owned = Uint8List.fromList(bytes);
          if (abandoned) {
            owned.fillRange(0, owned.length, 0);
            throw const KdfFailure(KdfFailureCode.cancelled);
          }
          return owned;
        })
        .whenComplete(() => _busy = false);
    native.ignore();
    try {
      return await Future.any([
        native,
        if (cancellation != null)
          cancellation.whenCancelled.then<Uint8List>(
            (_) => throw const KdfFailure(KdfFailureCode.cancelled),
          ),
      ]).timeout(
        deadline,
        onTimeout: () => throw const KdfFailure(KdfFailureCode.timedOut),
      );
    } on KdfFailure {
      abandoned = true;
      rethrow;
    } on PlatformException catch (error) {
      abandoned = true;
      throw KdfFailure(
        error.code == 'KDF_BUSY' ? KdfFailureCode.busy : KdfFailureCode.failed,
      );
    } catch (_) {
      abandoned = true;
      throw const KdfFailure(KdfFailureCode.failed);
    }
  }
}
