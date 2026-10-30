import 'support/native_results.dart';
import 'package:siraj/features/auth/kdf_worker.dart';
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
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  recordNativeResults(binding, 'native-kdf', 10);
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
          late Uint8List result;
          try {
            result = await NativePbkdf2().derive(
              password: v['password'] as String,
              salt: salt,
              iterations: v['iterations'] as int,
            );
          } on KdfFailure catch (error) {
            debugPrint(
              'SIRAJ_NATIVE_KDF_FAILURE vector=${v['id']} code=${error.code.name}',
            );
            rethrow;
          }
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
  testWidgets(
    'observing native completion permits back-to-back derives across workers',
    (tester) async {
      await tester.runAsync(() async {
        final workers = [NativePbkdf2(), NativePbkdf2()];
        for (var i = 0; i < 64; i++) {
          final result = await workers[i % 2].derive(
            password: 'password',
            salt: Uint8List.fromList(List.generate(16, (i) => i)),
            iterations: 1,
          );
          expect(
            result.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
            vectors.first['expected_hex'],
          );
          result.fillRange(0, result.length, 0);
        }
        debugPrint(
          'SIRAJ_NATIVE_COMPLETION sequential_calls=64 workers=2 PASS',
        );
      });
    },
  );
  testWidgets(
    'native global lane rejects concurrent worker and recovers after completion',
    (tester) async {
      await tester.runAsync(() async {
        final first = NativePbkdf2().derive(
          password: 'synthetic-native-contention',
          salt: Uint8List(16),
          iterations: 600000,
        );
        final drained = first.then((bytes) {
          bytes.fillRange(0, bytes.length, 0);
        });
        final second = NativePbkdf2();
        await expectLater(
          second.derive(
            password: 'synthetic-native-contention',
            salt: Uint8List(16),
            iterations: 1,
          ),
          throwsA(
            isA<KdfFailure>().having(
              (e) => e.code,
              'code',
              KdfFailureCode.busy,
            ),
          ),
        );
        await drained;
        final bytes = await second.derive(
          password: 'synthetic-native-contention',
          salt: Uint8List(16),
          iterations: 1,
        );
        expect(bytes, hasLength(32));
        bytes.fillRange(0, bytes.length, 0);
        debugPrint('SIRAJ_NATIVE_GLOBAL_LANE busy_then_recovered=true PASS');
      });
    },
  );
  testWidgets(
    'native cancellation settles logically and drains provider before retry',
    (tester) async {
      await tester.runAsync(() async {
        final worker = NativePbkdf2();
        final cancellation = KdfCancellation();
        final task = worker.derive(
          password: 'synthetic-native-cancel',
          salt: Uint8List(16),
          iterations: 600000,
          cancellation: cancellation,
        );
        final settled = task.then<Object?>(
          (_) => null,
          onError: (Object error) => error,
        );
        final watch = Stopwatch()..start();
        cancellation.cancel();
        final result = await settled;
        watch.stop();
        expect(
          result,
          isA<KdfFailure>().having(
            (e) => e.code,
            'code',
            KdfFailureCode.cancelled,
          ),
        );
        expect(watch.elapsedMilliseconds, lessThan(1000));
        await expectLater(
          worker.derive(
            password: 'synthetic',
            salt: Uint8List(16),
            iterations: 1,
          ),
          throwsA(
            isA<KdfFailure>().having(
              (e) => e.code,
              'code',
              KdfFailureCode.busy,
            ),
          ),
        );
        final drain = Stopwatch()..start();
        while (true) {
          try {
            final bytes = await worker.derive(
              password: 'synthetic',
              salt: Uint8List(16),
              iterations: 1,
            );
            expect(bytes.length, 32);
            bytes.fillRange(0, bytes.length, 0);
            break;
          } on KdfFailure catch (error) {
            if (error.code != KdfFailureCode.busy) rethrow;
            if (drain.elapsed > const Duration(seconds: 65)) {
              fail('Native provider did not drain');
            }
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        }
        debugPrint(
          'SIRAJ_NATIVE_CANCEL logical_cancel_ms=${watch.elapsedMilliseconds} provider_drained=true; no physical-device approval',
        );
      });
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
