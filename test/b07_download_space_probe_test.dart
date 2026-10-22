import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/resources/download_contracts.dart';
import 'package:siraj/features/resources/download_storage_space.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('siraj/download_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const probe = AndroidDownloadSpaceProbe();
  final directory = Directory('/isolated-app-private-staging');

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'requests real native availableBytes for the staging directory',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'availableBytes');
        expect(call.arguments, {'path': directory.absolute.path});
        return 987654321;
      });
      expect(await probe.availableBytes(directory), 987654321);
    },
  );

  for (final value in [null, -1]) {
    test('unknown native storage result $value is rejected', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => value);
      expect(probe.availableBytes(directory), throwsA(isA<DownloadFailure>()));
    });
  }

  test(
    'native path/IO failure is a typed storage-unavailable failure',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'storage_unavailable'),
      );
      expect(
        probe.availableBytes(directory),
        throwsA(
          isA<DownloadFailure>().having(
            (e) => e.code,
            'code',
            DownloadFailureCode.storageUnavailable,
          ),
        ),
      );
    },
  );

  test('missing native capability never fabricates free space', () async {
    expect(
      probe.availableBytes(directory),
      throwsA(
        isA<DownloadFailure>().having(
          (e) => e.code,
          'code',
          DownloadFailureCode.storageUnavailable,
        ),
      ),
    );
  });
}
