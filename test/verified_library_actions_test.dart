import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/core/runtime/resource_cleanup_owner.dart';
import 'package:siraj/features/library/library_contracts.dart';
import 'package:siraj/features/library/pdf_install_store.dart';
import 'package:siraj/features/library/pdf_reader_contracts.dart';
import 'package:siraj/features/library/verified_library_actions.dart';
import 'package:siraj/features/resources/download_contracts.dart';
import 'package:siraj/features/resources/download_service.dart';
import 'package:siraj/features/resources/download_staging.dart';
import 'package:siraj/features/resources/resource_download_validator.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';
import 'support/download_server.dart';
import 'support/pdf_fixture.dart';
import 'pdf_install_store_test.dart' show Space;

class Reader implements PdfReaderPort {
  @override
  bool get available => true;
  bool reject = false, failClose = false;
  int opens = 0, renders = 0, closes = 0;
  Completer<void>? hold;
  @override
  Future<PdfDocumentPort> open(File file) async {
    opens++;
    if (reject) throw const PdfFailure(PdfFailureCode.invalidFile);
    return Doc(this);
  }
}

class Doc implements PdfDocumentPort {
  Doc(this.owner);
  final Reader owner;
  @override
  String get id => 'test-${owner.opens}';
  @override
  int get pageCount => 2;
  @override
  Future<PdfPageImage> render(int page, {required int width}) async {
    owner.renders++;
    await owner.hold?.future;
    return PdfPageImage(
      documentId: id,
      page: page,
      width: width,
      height: 400,
      png: Uint8List(1),
    );
  }

  @override
  Future<void> close() async {
    owner.closes++;
    if (owner.failClose) throw const PdfFailure(PdfFailureCode.ioFailure);
  }
}

void main() {
  late Directory root;
  late DownloadTestServer server;
  late PdfLibraryStorage storage;
  late VerifiedLibraryActions actions;
  late LibraryBook book;
  late Reader reader;
  late ResourceCleanupOwner cleanup;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('siraj-pdf-actions-');
    server = await DownloadTestServer.start();
    final bytes = syntheticPdf();
    server.respond = (r, _) => DownloadTestServer.full(r, bytes);
    final file = await File('${root.path}/input').writeAsBytes(bytes);
    final spec = DownloadSpec(
      resourceId: 'test-pdf',
      artifactRevision: 'test-1',
      kind: ResourceContractKind.pdf,
      url: server.url,
      destinationKey: 'book-test',
      maxBytes: 10000,
      expectedSize: bytes.length,
      expectedSha256: await DownloadStaging.hashFile(file),
    );
    book = LibraryBook(
      id: 'test',
      arabicTitle: 'اختبار',
      englishTitle: 'Test',
      categoryId: 'test',
      categoryArabic: 'اختبار',
      categoryEnglish: 'Test',
      download: spec,
    );
    final space = Space();
    storage = PdfLibraryStorage(
      PdfInstallStore(root, space),
      DownloadService(
        appSupportDirectory: root,
        spaceProbe: space,
        validator: const ResourceDownloadValidator(),
        clientFactory: server.client,
      ),
    );
    reader = Reader();
    cleanup = ResourceCleanupOwner();
    actions = VerifiedLibraryActions(
      storage: () => Future.value(storage),
      reader: reader,
      cleanup: cleanup,
      present: (_, _) async {},
    );
  });
  tearDown(() async {
    reader.failClose = false;
    await cleanup.retry();
    await server.close();
    await root.delete(recursive: true);
  });
  test(
    'TLS download, native proof, final installation, independent offline reopen',
    () async {
      expect(await actions.inspect(book), BookFileState.missing);
      await actions.download(book);
      expect(server.requests, hasLength(1));
      expect(reader.renders, 1);
      expect(await actions.inspect(book), BookFileState.readable);
      await server.close();
      await actions.open(book);
      final lease = await storage.store.acquire(book.download);
      expect(await lease.hasVerifiedBook(), isTrue);
      expect(lease.book.path, isNot(contains('staging')));
      await lease.release();
    },
  );
  test('parser rejection cannot promote PDF header alone', () async {
    reader.reject = true;
    await expectLater(actions.download(book), throwsA(isA<PdfFailure>()));
    final lease = await storage.store.acquire(book.download);
    expect(await lease.hasVerifiedBook(), isFalse);
    await lease.release();
    expect(await actions.inspect(book), isNot(BookFileState.readable));
  });
  test(
    'cancel during parser proof never promotes; restart reuses trusted download',
    () async {
      reader.hold = Completer<void>();
      final job = expectLater(
        actions.download(book),
        throwsA(isA<PdfFailure>()),
      );
      while (reader.renders == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await actions.cancel(book);
      reader.hold!.complete();
      await job;
      final lease = await storage.store.acquire(book.download);
      expect(await lease.hasVerifiedBook(), isFalse);
      await lease.release();
      reader.hold = null;
      await actions.download(book);
      expect(server.requests, hasLength(1));
      expect(await actions.inspect(book), BookFileState.readable);
    },
  );
  test(
    'failed native close retains file pin until app-scoped recovery',
    () async {
      reader.failClose = true;
      await expectLater(actions.download(book), throwsA(isA<PdfFailure>()));
      expect(cleanup.needsRetry, isTrue);
      await expectLater(
        storage.store.acquire(book.download),
        throwsA(isA<PdfFailure>()),
      );
      reader.failClose = false;
      await cleanup.retry();
      expect(cleanup.needsRetry, isFalse);
      final lease = await storage.store.acquire(book.download);
      expect(await lease.hasVerifiedBook(), isFalse);
      await lease.release();
    },
  );
}
