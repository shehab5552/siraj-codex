import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/library/native_pdf_reader.dart';
import 'package:siraj/features/library/pdf_reader_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('siraj/pdf');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test('typed platform failures and missing engine fail closed', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(
            code: 'unsafe_path',
            message: 'private path must never reach UI',
          ),
        );
    await expectLater(
      const NativePdfReader().open(File('/not-allowed.pdf')),
      throwsA(
        isA<PdfFailure>().having(
          (e) => e.code,
          'code',
          PdfFailureCode.unsafePath,
        ),
      ),
    );
  });
  test(
    'rejects malformed replies; handles are closed on invalid open metadata',
    () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return call.method == 'open'
                ? {'id': 'owned-id', 'pages': 0}
                : null;
          });
      await expectLater(
        const NativePdfReader().open(File('/test.pdf')),
        throwsA(isA<PdfFailure>()),
      );
      expect(calls, ['open', 'close']);
    },
  );
  test('render checks PNG, identity, dimensions and closed handle', () async {
    var invalid = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => switch (call.method) {
            'open' => {'id': 'owned-id', 'pages': 2},
            'render' => {
              'id': invalid ? 'wrong-id' : 'owned-id',
              'page': 0,
              'width': 300,
              'height': 400,
              'png': Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
            },
            _ => null,
          },
        );
    final doc = await const NativePdfReader().open(File('/test.pdf'));
    await expectLater(doc.render(0, width: 300), throwsA(isA<PdfFailure>()));
    invalid = false;
    expect((await doc.render(0, width: 300)).height, 400);
    await doc.close();
    await expectLater(doc.render(0, width: 300), throwsA(isA<PdfFailure>()));
  });
}
