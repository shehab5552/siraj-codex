import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:siraj/features/auth/native_pbkdf2.dart';

// Independent OpenSSL vectors, synthetic inputs copied from the reviewed fixture.
final vectors =
    jsonDecode(
          r'''[{"id": "ascii-1", "password": "password", "salt_hex": "000102030405060708090a0b0c0d0e0f", "iterations": 1, "expected_hex": "e1b08f92be8174d9f442d95d89aa4ccdc311231a4d70d0b854d1548de8fabdfd"}, {"id": "ascii-2", "password": "password", "salt_hex": "000102030405060708090a0b0c0d0e0f", "iterations": 2, "expected_hex": "a0ffd34292e4e7d519ee0f25124e0c5b9481d88be40f4662eb6cb4b9e43f9f41"}, {"id": "ascii-4096", "password": "password", "salt_hex": "000102030405060708090a0b0c0d0e0f", "iterations": 4096, "expected_hex": "91700e3c494e10071700866601efd486e43765fa8b42b9a129203386a5ca509b"}, {"id": "unicode", "password": "كلمة_تجريبية🔐", "salt_hex": "000102030405060708090a0b0c0d0e0f", "iterations": 4096, "expected_hex": "4b6630ad6af5ae5856d70d7c9de0f6e6710b1710e78ba49a6741fedc6bd49f19"}, {"id": "embedded-nul", "password": "pass\u0000word", "salt_hex": "000102030405060708090a0b0c0d0e0f", "iterations": 4096, "expected_hex": "228a831afcdf4d7b61d3a8695c6cab1d931550a09aa906c1c7b283fd6091aa2e"}, {"id": "long-hmac-key", "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "salt_hex": "000102030405060708090a0b0c0d0e0f", "iterations": 4096, "expected_hex": "56256a136f7cecb871db1e9ba841679f9b90820eadfa14b4557591239f69e5db"}, {"id": "candidate-600k", "password": "independent-test-vector", "salt_hex": "000102030405060708090a0b0c0d0e0f", "iterations": 600000, "expected_hex": "a8c72883c1839f5068abcb17cbc532d68a5562ce194927f62d1310484d510059"}]''',
        )
        as List;
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final v in vectors) {
    testWidgets('native Android PBKDF2 vector ${v['id']}', (tester) async {
      expect(Platform.isAndroid, isTrue);
      await tester.runAsync(() async {
        final watch = Stopwatch()..start();
        var ticks = 0;
        final timer = Timer.periodic(
          const Duration(milliseconds: 10),
          (_) => ticks++,
        );
        try {
          final hex = v['salt_hex'] as String;
          final salt = Uint8List.fromList([
            for (var i = 0; i < hex.length; i += 2)
              int.parse(hex.substring(i, i + 2), radix: 16),
          ]);
          final result = await NativePbkdf2().derive(
            password: v['password'] as String,
            salt: salt,
            iterations: v['iterations'] as int,
          );
          expect(
            result.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
            v['expected_hex'],
          );
          result.fillRange(0, result.length, 0);
          if (v['iterations'] == 600000) {
            expect(ticks, greaterThan(0));
            debugPrint(
              'SIRAJ_NATIVE_KDF_METRICS ${jsonEncode({'iterations': 600000, 'elapsed_ms': watch.elapsedMilliseconds, 'heartbeat_ticks': ticks, 'physical_device': false, 'production_approved': false})}',
            );
          }
        } finally {
          timer.cancel();
        }
      });
    });
  }
}
