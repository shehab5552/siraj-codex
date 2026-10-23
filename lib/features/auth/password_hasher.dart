import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'kdf_worker.dart';

/// Persist only the salt, derived hash and parameters in SQLite.
/// NEVER persist or log the original password.
class PasswordCredential {
  const PasswordCredential({
    required this.salt,
    required this.hash,
    required this.parametersJson,
  });

  final Uint8List salt;
  final Uint8List hash;
  final String parametersJson;
}

/// Implements DD-05: PBKDF2-HMAC-SHA256 and constant-work byte comparison.
///
/// The production iteration count MUST be selected after Android benchmarking
/// and security review. There is deliberately no production default here.
class PasswordHasher {
  PasswordHasher({required this.iterations, IsolatePbkdf2? worker})
    : _worker = worker ?? IsolatePbkdf2() {
    if (iterations <= 0 || iterations > maxSupportedIterations) {
      throw RangeError.range(
        iterations,
        1,
        maxSupportedIterations,
        'iterations',
      );
    }
  }

  static const algorithm = 'PBKDF2-HMAC-SHA256';
  static const saltBytes = 16;
  static const hashBits = 256;
  static const hashBytes = hashBits ~/ 8;
  static const maxSupportedIterations = 5000000;
  // Security review candidate (OWASP floor), NOT Android-approved production.
  static const candidateIterations = 600000;
  static const maxPasswordBytes = 1024;
  static const maxParametersLength = 4096;

  final int iterations;
  final IsolatePbkdf2 _worker;

  Future<PasswordCredential> hashPassword(
    String password, {
    KdfCancellation? cancellation,
  }) async {
    if (password.isEmpty || utf8.encode(password).length > maxPasswordBytes) {
      throw ArgumentError.value('', 'password', 'Password must not be empty');
    }

    // A fresh, cryptographically secure salt for every new account.
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(saltBytes, (_) => random.nextInt(256)),
    );
    final hash = await _worker.derive(
      password: password,
      salt: salt,
      iterations: iterations,
      cancellation: cancellation,
    );
    return PasswordCredential(
      salt: salt,
      hash: hash,
      parametersJson: jsonEncode(<String, Object>{
        'kdf': algorithm,
        'iterations': iterations,
        'bits': hashBits,
      }),
    );
  }

  /// Rebuild the verifier using the *stored* parameters (not the currently
  /// chosen signup parameters), so existing passwords remain verifiable.
  Future<bool> verifyPassword({
    required String password,
    required Uint8List salt,
    required Uint8List expectedHash,
    required String parametersJson,
    KdfCancellation? cancellation,
  }) async {
    if (password.isEmpty ||
        utf8.encode(password).length > maxPasswordBytes ||
        parametersJson.length > maxParametersLength ||
        salt.length != saltBytes ||
        expectedHash.length != hashBytes) {
      return false;
    }
    final Map<String, dynamic> params;
    try {
      final decoded = jsonDecode(parametersJson);
      if (decoded is! Map<String, dynamic>) return false;
      params = decoded;
    } on FormatException {
      return false;
    }

    final storedIterations = params['iterations'];
    if (params['kdf'] != algorithm ||
        params['bits'] != hashBits ||
        storedIterations is! int ||
        storedIterations < 1 ||
        storedIterations > maxSupportedIterations) {
      return false;
    }

    final actualHash = await _worker.derive(
      password: password,
      salt: salt,
      iterations: storedIterations,
      cancellation: cancellation,
    );
    try {
      return constantTimeEquals(actualHash, expectedHash);
    } finally {
      actualHash.fillRange(0, actualHash.length, 0);
    }
  }

  /// Does not stop comparing after the first mismatched byte.
  /// Length mismatch is also folded into the final result.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    var difference = a.length ^ b.length;
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final left = i < a.length ? a[i] : 0;
      final right = i < b.length ? b[i] : 0;
      difference |= left ^ right;
    }
    return difference == 0;
  }
}
