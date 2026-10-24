import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/auth/kdf_worker.dart';
import 'package:siraj/features/auth/native_pbkdf2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('siraj/password_kdf');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  Future<Uint8List> derive(NativePbkdf2 worker, {KdfCancellation? cancel}) =>
      worker.derive(
        password: 'كلمة🔒\u0000مرور',
        salt: Uint8List(16),
        iterations: 600000,
        cancellation: cancel,
      );
  test('native result is checked and no secret appears in failures', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => Uint8List(31));
    await expectLater(
      derive(NativePbkdf2()),
      throwsA(
        isA<KdfFailure>().having((e) => e.code, 'code', KdfFailureCode.failed),
      ),
    );
  });
  test(
    'cancel releases caller but keeps lane until native completion',
    () async {
      final response = Completer<Uint8List>();
      messenger.setMockMethodCallHandler(channel, (call) => response.future);
      final worker = NativePbkdf2();
      final cancel = KdfCancellation();
      final pending = derive(worker, cancel: cancel);
      final cancelled = expectLater(
        pending,
        throwsA(
          isA<KdfFailure>().having(
            (e) => e.code,
            'code',
            KdfFailureCode.cancelled,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      cancel.cancel();
      await cancelled;
      await expectLater(
        derive(worker),
        throwsA(
          isA<KdfFailure>().having((e) => e.code, 'code', KdfFailureCode.busy),
        ),
      );
      response.complete(Uint8List(32));
      await Future<void>.delayed(Duration.zero);
      expect(await derive(worker), hasLength(32));
    },
  );
  test(
    'deadline holds ownership and late native failure is consumed',
    () async {
      final response = Completer<Uint8List>();
      messenger.setMockMethodCallHandler(channel, (call) => response.future);
      final worker = NativePbkdf2(deadline: const Duration(milliseconds: 10));
      await expectLater(
        derive(worker),
        throwsA(
          isA<KdfFailure>().having(
            (e) => e.code,
            'code',
            KdfFailureCode.timedOut,
          ),
        ),
      );
      await expectLater(
        derive(worker),
        throwsA(
          isA<KdfFailure>().having((e) => e.code, 'code', KdfFailureCode.busy),
        ),
      );
      response.completeError(
        PlatformException(code: 'KDF_FAILED', message: 'sensitive detail'),
      );
      await Future<void>.delayed(Duration.zero);
    },
  );
  test('invalid parameters and prior cancellation never dispatch', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      return Uint8List(32);
    });
    final worker = NativePbkdf2();
    final cancel = KdfCancellation()..cancel();
    await expectLater(
      derive(worker, cancel: cancel),
      throwsA(isA<KdfFailure>()),
    );
    await expectLater(
      worker.derive(password: 'p', salt: Uint8List(16), iterations: 5000001),
      throwsArgumentError,
    );
    expect(calls, 0);
  });
  test(
    'platform byte views are copied into owned mutable verifier memory',
    () async {
      messenger.setMockMessageHandler(channel.name, (message) async {
        final envelope = const StandardMethodCodec().encodeSuccessEnvelope(
          Uint8List.fromList(List.filled(32, 7)),
        );
        return envelope.buffer
            .asUint8List()
            .asUnmodifiableView()
            .buffer
            .asByteData();
      });
      final bytes = await derive(NativePbkdf2());
      expect(bytes.first, 7);
      bytes.fillRange(0, bytes.length, 0);
      expect(bytes.every((b) => b == 0), isTrue);
    },
  );
}
