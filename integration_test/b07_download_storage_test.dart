import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:siraj/features/resources/download_contracts.dart';
import 'package:siraj/features/resources/download_storage_space.dart';

/// Uses isolated Android app-private temp files; no model/runtime is loaded.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('B-07 native StatFs measures private staging space', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    final directory = await Directory.systemTemp.createTemp('b07_storage_');
    try {
      final bytes = await const AndroidDownloadSpaceProbe().availableBytes(
        directory,
      );
      expect(bytes, greaterThan(0));
    } finally {
      await directory.delete();
    }
  });

  testWidgets('B-07 native boundary rejects outside private staging', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    await expectLater(
      const AndroidDownloadSpaceProbe().availableBytes(Directory('/')),
      throwsA(
        isA<DownloadFailure>().having(
          (error) => error.code,
          'code',
          DownloadFailureCode.storageUnavailable,
        ),
      ),
    );
  });
}
