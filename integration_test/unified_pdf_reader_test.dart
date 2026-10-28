import 'support/native_results.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/core/runtime/resource_cleanup_owner.dart';
import 'package:siraj/features/library/library_contracts.dart';
import 'package:siraj/features/library/native_pdf_reader.dart';
import 'package:siraj/features/library/pdf_install_store.dart';
import 'package:siraj/features/library/pdf_reader_contracts.dart';
import 'package:siraj/features/library/pdf_reader_page.dart';
import 'package:siraj/features/library/verified_library_actions.dart';
import 'package:siraj/features/resources/download_contracts.dart';
import 'package:siraj/features/resources/download_service.dart';
import 'package:siraj/features/resources/download_staging.dart';
import 'package:siraj/features/resources/download_storage_space.dart';
import 'package:siraj/features/resources/resource_download_validator.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';
import '../test/support/pdf_fixture.dart';

/// Framework PdfRenderer, real files/FDs/PNGs, no mock MethodChannel. The
/// synthetic PDF is test-only. No claim about an official textbook is made.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  recordNativeResults(binding, 'native-pdf', 1);
  testWidgets(
    'real Android PDF install render navigate offline reopen and path denial',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      final support = await NativePdfReader.appSupport();
      final source = await File(
        '${Directory.systemTemp.path}/synthetic-native.pdf',
      ).writeAsBytes(syntheticPdf(), flush: true);
      final spec = DownloadSpec(
        resourceId: 'native-pdf-test-only',
        artifactRevision: 'test-1',
        kind: ResourceContractKind.pdf,
        url: Uri.parse('https://example.invalid/test-only.pdf'),
        destinationKey: 'native-pdf-test-only',
        maxBytes: 10000,
        expectedSize: await source.length(),
        expectedSha256: await DownloadStaging.hashFile(source),
      );
      const space = AndroidDownloadSpaceProbe();
      final store = PdfInstallStore(support, space);
      // Seed B07's real completed provenance under its writer lease. HTTPS is
      // independently exercised by the host TLS tests, not claimed here.
      final staging = await DownloadStaging.acquire(
        support,
        spec.destinationKey,
      );
      try {
        if (await staging.completedFor(spec) == null) {
          final out = await staging.openPayload(append: false);
          try {
            await out.writeFrom(await source.readAsBytes());
            await out.flush();
          } finally {
            await out.close();
          }
          await staging.saveCheckpoint(
            spec,
            etag: '"synthetic-1"',
            total: spec.expectedSize,
            complete: true,
          );
        }
      } finally {
        await staging.release();
      }
      final storage = PdfLibraryStorage(
        store,
        DownloadService(
          appSupportDirectory: support,
          spaceProbe: space,
          validator: const ResourceDownloadValidator(),
        ),
      );
      final cleanup = ResourceCleanupOwner();
      final actions = VerifiedLibraryActions(
        storage: () => Future.value(storage),
        reader: const NativePdfReader(),
        cleanup: cleanup,
        present: (c, book) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: SirajTheme.light(),
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: PdfReaderPage(
                  controller: c,
                  arabicTitle: book.arabicTitle,
                  englishTitle: book.englishTitle,
                ),
              ),
            ),
          );
          final watch = Stopwatch()..start();
          while (c.image == null &&
              c.failure == null &&
              watch.elapsed < const Duration(seconds: 30)) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(c.failure, isNull);
          expect(c.image, isNotNull);
          expect(c.pageCount, 2);
          final first = c.image!.png.toList();
          await tester.tap(find.byKey(const Key('pdf-next')));
          while (c.image == null &&
              c.failure == null &&
              watch.elapsed < const Duration(seconds: 60)) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(c.image!.page, 1);
          expect(c.image!.png, isNot(orderedEquals(first)));
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
          final screenshot = await binding.takeScreenshot(
            'siraj-native-pdf-reader',
          );
          await File(
            '${Directory.systemTemp.path}/siraj-native-pdf-reader.png',
          ).writeAsBytes(screenshot, flush: true);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
      final book = LibraryBook(
        id: 'synthetic-native',
        arabicTitle: 'مستند اختبار اصطناعي',
        englishTitle: 'Synthetic native test',
        categoryId: 'test',
        categoryArabic: 'اختبار',
        categoryEnglish: 'Test',
        download: spec,
      );
      await actions.download(book);
      expect(await actions.inspect(book), BookFileState.readable);
      await actions.open(book);
      await cleanup.drain();
      expect(cleanup.needsRetry, isFalse);
      final lease = await store.acquire(spec);
      expect(await lease.hasVerifiedBook(), isTrue);
      final doc = await const NativePdfReader().open(lease.book);
      expect(doc.pageCount, 2);
      await expectLater(doc.render(2, width: 300), throwsA(isA<PdfFailure>()));
      await expectLater(doc.render(0, width: 2049), throwsA(isA<PdfFailure>()));
      await doc.close();
      await doc.close();
      await expectLater(doc.render(0, width: 300), throwsA(isA<PdfFailure>()));
      await lease.release();
      await expectLater(
        const NativePdfReader().open(source),
        throwsA(isA<PdfFailure>()),
      );
      // Hash/header success cannot make a malformed document readable.
      final bad = await store.acquire(
        DownloadSpec(
          resourceId: 'malformed-test',
          artifactRevision: 'test-1',
          kind: ResourceContractKind.pdf,
          url: Uri.parse('https://example.invalid/malformed'),
          destinationKey: 'malformed-test',
          maxBytes: 10000,
          expectedSize: spec.expectedSize,
          expectedSha256: spec.expectedSha256,
        ),
      );
      final malformed = File('${bad.directory.path}/candidate.pdf');
      await malformed.writeAsString('%PDF-1.4\nnot a document');
      await expectLater(
        const NativePdfReader().open(malformed),
        throwsA(isA<PdfFailure>()),
      );
      await bad.release();
      await source.delete();
      debugPrint(
        'SIRAJ_UNIFIED_ANDROID PDF native parser/install/render/page navigation/offline reopen/bounds/path denial/malformed/close PASS; synthetic PDF; emulator only',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
