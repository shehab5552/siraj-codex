import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:siraj/app/app_bootstrap.dart';
import 'package:siraj/app/app_session_controller.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/database_runtime.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'package:siraj/features/library/library_page.dart';
import 'support/auth_test_marker.dart';
import 'support/pump_real_future.dart';
import 'dart:io';
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
import 'support/pdf_fixture.dart';
import 'verified_library_actions_test.dart' show Reader;
import 'pdf_install_store_test.dart' show Space;

class SingleBookCatalog implements ApprovedLibraryCatalog {
  SingleBookCatalog(this.book);
  final LibraryBook book;
  @override
  Future<List<LibraryBook>?> read() async => [book];
}

void main() {
  for (final failClose in [false, true]) {
    testWidgets(
      'session navigator destruction drains PDF file lease closeFailure=$failClose',
      (t) async {
        late Directory root;
        late PdfLibraryStorage storage;
        late VerifiedLibraryActions actions;
        late LibraryBook book;
        final reader = Reader();
        final cleanup = ResourceCleanupOwner();
        await t.runAsync(() async {
          root = await Directory.systemTemp.createTemp('siraj-pdf-session-');
          final source = await File(
            '${root.path}/input',
          ).writeAsBytes(syntheticPdf());
          final spec = DownloadSpec(
            resourceId: 'session-test',
            artifactRevision: 'test-1',
            kind: ResourceContractKind.pdf,
            url: Uri.parse('https://example.invalid/synthetic'),
            destinationKey: 'session-test',
            maxBytes: 10000,
            expectedSize: await source.length(),
            expectedSha256: await DownloadStaging.hashFile(source),
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
          final staging = await DownloadStaging.acquire(
            root,
            spec.destinationKey,
          );
          try {
            final file = await staging.openPayload(append: false);
            try {
              await file.writeFrom(await source.readAsBytes());
              await file.flush();
            } finally {
              await file.close();
            }
            await staging.saveCheckpoint(
              spec,
              etag: '"test"',
              total: spec.expectedSize,
              complete: true,
            );
          } finally {
            await staging.release();
          }
          final space = Space();
          storage = PdfLibraryStorage(
            PdfInstallStore(root, space),
            DownloadService(
              appSupportDirectory: root,
              spaceProbe: space,
              validator: const ResourceDownloadValidator(),
            ),
          );
          actions = VerifiedLibraryActions(
            storage: () => Future.value(storage),
            reader: reader,
            cleanup: cleanup,
            present: (_, _) async {},
          );
        });
        final runtime = DatabaseRuntime(
          createDatabase: () => AppDatabase.forTesting(NativeDatabase.memory()),
        );
        final session = AppSessionController(
          runtime: runtime,
          markerStore: ControlledMarker(),
          passwordHasher: PasswordHasher(iterations: 2),
        );
        await t.runAsync(() async {
          await session.initialize();
          await session.createAccount(
            username: 'PDF test',
            password: 'test-only',
            confirmation: 'test-only',
          );
          await actions.download(book);
        });
        actions = VerifiedLibraryActions(
          storage: () => Future.value(storage),
          reader: reader,
          cleanup: cleanup,
          present: (c, _) {
            reader.failClose = failClose;
            return Navigator.of(t.element(find.byType(LibraryPage))).push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('owned PDF route')),
              ),
            );
          },
        );
        Future<void> until(Finder finder) async {
          for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 15)),
            );
            await t.pump(const Duration(milliseconds: 50));
          }
          expect(finder, findsWidgets);
        }

        try {
          await t.pumpWidget(
            MaterialApp(
              home: AppBootstrap(
                sessionController: session,
                library: LibraryIntegration(
                  catalog: SingleBookCatalog(book),
                  actions: actions,
                ),
              ),
            ),
          );
          await until(find.byType(NavigationBar));
          await t.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text('المكتبة الدراسية'),
            ),
          );
          await until(find.byKey(const Key('library-open-test')));
          await t.tap(find.byKey(const Key('library-open-test')));
          await until(find.text('owned PDF route'));
          await t.runAsync(session.logout);
          await until(find.byKey(const Key('login-submit')));
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          if (failClose) {
            expect(cleanup.needsRetry, isTrue);
            await t.runAsync(
              () => expectLater(
                storage.store.acquire(book.download),
                throwsA(isA<PdfFailure>()),
              ),
            );
            reader.failClose = false;
            await pumpRealFuture(t, cleanup.retry());
          }
          final lease = await pumpRealFuture(
            t,
            storage.store.acquire(book.download),
          );
          expect(await pumpRealFuture(t, lease.hasVerifiedBook()), isTrue);
          await pumpRealFuture(t, lease.release());
          expect(t.takeException(), isNull);
        } finally {
          reader.failClose = false;
          await t.pumpWidget(const SizedBox());
          await pumpRealFuture(t, cleanup.retry());
          session.dispose();
          await pumpRealFuture(t, runtime.close());
          await t.runAsync(() => root.delete(recursive: true));
        }
      },
    );
  }
}
