import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/auth/password_hasher.dart';

void main() {
  // Test work factor is deliberately tiny. Do not use it for real accounts.
  final hasher = PasswordHasher(iterations: 10);

  test('B-04: correct password verifies; incorrect password fails', () async {
    final saved = await hasher.hashPassword('secret-for-unit-test');
    expect(saved.salt.length, PasswordHasher.saltBytes);
    expect(saved.hash.length, PasswordHasher.hashBytes);
    expect(
      await hasher.verifyPassword(
        password: 'secret-for-unit-test',
        salt: saved.salt,
        expectedHash: saved.hash,
        parametersJson: saved.parametersJson,
      ),
      isTrue,
    );
    expect(
      await hasher.verifyPassword(
        password: 'wrong-password',
        salt: saved.salt,
        expectedHash: saved.hash,
        parametersJson: saved.parametersJson,
      ),
      isFalse,
    );
  });

  test('B-04: same password gets independent random salts', () async {
    final first = await hasher.hashPassword('same-password');
    final second = await hasher.hashPassword('same-password');
    expect(first.salt, isNot(orderedEquals(second.salt)));
    expect(first.hash, isNot(orderedEquals(second.hash)));
  });

  test('B-04: stored parameters control verification', () async {
    final created = await hasher.hashPassword('stored-settings');
    final upgraded = PasswordHasher(iterations: 20);
    expect(
      await upgraded.verifyPassword(
        password: 'stored-settings',
        salt: created.salt,
        expectedHash: created.hash,
        parametersJson: created.parametersJson,
      ),
      isTrue,
    );
    final params = jsonDecode(created.parametersJson) as Map<String, dynamic>;
    expect(params['kdf'], PasswordHasher.algorithm);
    expect(params['iterations'], 10);
    expect(params['bits'], 256);
  });

  test('B-04: tampered hashes and malformed parameters fail closed', () async {
    final saved = await hasher.hashPassword('tamper-check');
    final modified = Uint8List.fromList(saved.hash);
    modified[0] ^= 1;
    for (final parameters in <String>[
      '{}',
      'not-json',
      '{"kdf":"WRONG","iterations":10,"bits":256}',
      '{"kdf":"PBKDF2-HMAC-SHA256","iterations":999999999,"bits":256}',
    ]) {
      expect(
        await hasher.verifyPassword(
          password: 'tamper-check',
          salt: saved.salt,
          expectedHash: saved.hash,
          parametersJson: parameters,
        ),
        isFalse,
      );
    }
    expect(
      await hasher.verifyPassword(
        password: 'tamper-check',
        salt: saved.salt,
        expectedHash: modified,
        parametersJson: saved.parametersJson,
      ),
      isFalse,
    );
  });

  test('B-04: compare checks every byte; no plaintext in parameters', () async {
    expect(PasswordHasher.constantTimeEquals([1, 2], [1, 2]), isTrue);
    expect(PasswordHasher.constantTimeEquals([1, 2], [1, 3]), isFalse);
    expect(PasswordHasher.constantTimeEquals([1, 2], [1]), isFalse);
    final saved = await hasher.hashPassword('never-write-this-password');
    expect(saved.parametersJson, isNot(contains('never-write-this-password')));
    await expectLater(hasher.hashPassword(''), throwsArgumentError);
    expect(() => PasswordHasher(iterations: 0), throwsRangeError);
  });
}
