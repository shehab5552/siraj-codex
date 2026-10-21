import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

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
  PasswordHasher({required this.iterations}) {
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

  final int iterations;

  Future<PasswordCredential> hashPassword(String password) async {
    if (password.isEmpty) {
      throw ArgumentError.value('', 'password', 'Password must not be empty');
    }

    // A fresh, cryptographically secure salt for every new account.
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(saltBytes, (_) => random.nextInt(256)),
    );
    final hash = await _derive(password, salt, iterations);
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
  }) async {
    if (password.isEmpty ||
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

    final actualHash = await _derive(password, salt, storedIterations);
    return constantTimeEquals(actualHash, expectedHash);
  }

  static Future<Uint8List> _derive(
    String password,
    List<int> salt,
    int iterations,
  ) async {
    final pbkdf2 = Pbkdf2.hmacSha256(iterations: iterations, bits: hashBits);
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    // Some cryptography implementations return a sensitive buffer backed by
    // the secret key itself. Copy its bytes BEFORE destroying that key.
    try {
      final bytes = await secretKey.extractBytes();
      return Uint8List.fromList(bytes);
    } finally {
      secretKey.destroy();
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
