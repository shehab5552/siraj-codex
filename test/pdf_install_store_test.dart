import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/library/pdf_install_store.dart';
import 'package:siraj/features/library/pdf_reader_contracts.dart';
import 'package:siraj/features/resources/download_contracts.dart';
import 'package:siraj/features/resources/download_staging.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';
import 'support/pdf_fixture.dart';

class Space implements DownloadSpaceProbe {
  int bytes = 10000000;
  @override
  Future<int> availableBytes(Directory directory) async => bytes;
}

void main() {
  late Directory root;
  late File source;
  late DownloadSpec spec;
  late Space space;
  late PdfInstallStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('siraj-pdf-install-');
    source = await File('${root.path}/input.pdf').writeAsBytes(syntheticPdf());
    spec = DownloadSpec(
      resourceId: 'synthetic',
      artifactRevision: 'test-1',
      kind: ResourceContractKind.pdf,
      url: Uri.parse('https://example.invalid/test.pdf'),
      destinationKey: 'synthetic-pdf',
      maxBytes: 10000,
      expectedSize: await source.length(),
      expectedSha256: await DownloadStaging.hashFile(source),
    );
    space = Space();
    store = PdfInstallStore(root, space);
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  test(
    'private immutable identity installation, promotion, offline hash proof',
    () async {
      final lease = await store.acquire(spec);
      expect(await lease.hasVerifiedBook(), isFalse);
      final candidate = await lease.prepare(source);
      expect(candidate.path, endsWith('/candidate.pdf'));
      expect(await lease.hasVerifiedBook(), isFalse);
      await lease.promote(); // caller must first close native readability proof
      expect(await lease.hasVerifiedBook(), isTrue);
      expect(lease.book.path, endsWith('/book.pdf'));
      await expectLater(store.acquire(spec), throwsA(isA<PdfFailure>()));
      await expectLater(lease.prepare(source), throwsA(isA<PdfFailure>()));
      await lease.release();
      final reopened = await store.acquire(spec);
      expect(await reopened.hasVerifiedBook(), isTrue);
      await reopened.release();
    },
  );
  test('wrong bytes cannot promote; disk space fails closed', () async {
    final lease = await store.acquire(spec);
    await source.writeAsString('%PDF-1.4\nwrong');
    await expectLater(lease.prepare(source), throwsA(isA<PdfFailure>()));
    expect(await lease.hasVerifiedBook(), isFalse);
    await source.writeAsBytes(syntheticPdf());
    space.bytes = 0;
    await expectLater(lease.prepare(source), throwsA(isA<DownloadFailure>()));
    await lease.release();
  });
  test(
    'symlink leaf and foreign contents never authorize deleting targets',
    () async {
      final lease = await store.acquire(spec);
      final path = lease.book.path;
      await lease.release();
      await Link(path).create(source.path);
      await expectLater(store.acquire(spec), throwsA(isA<PdfFailure>()));
      expect(await source.readAsBytes(), syntheticPdf());
    },
  );
  test(
    'corrupted final is detected and repair cannot run while leased',
    () async {
      final lease = await store.acquire(spec);
      await lease.prepare(source);
      await lease.promote();
      await lease.book.writeAsString('corrupt');
      expect(await lease.hasVerifiedBook(), isFalse);
      await expectLater(store.acquire(spec), throwsA(isA<PdfFailure>()));
      await lease.prepare(source);
      await lease.promote();
      expect(await lease.hasVerifiedBook(), isTrue);
      await lease.release();
    },
  );
}
