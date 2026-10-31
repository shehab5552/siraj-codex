import 'dart:async';
import '../../core/runtime/resource_cleanup_owner.dart';
import '../resources/download_contracts.dart';
import '../resources/download_service.dart';
import '../resources/resource_download_validator.dart';
import 'library_contracts.dart';
import 'pdf_install_store.dart';
import 'pdf_reader_contracts.dart';
import 'pdf_reader_controller.dart';

class PdfLibraryStorage {
  const PdfLibraryStorage(this.store, this.downloads);
  final PdfInstallStore store;
  final DownloadService<ResourceDownloadEvidence> downloads;
}

class _Operation {
  bool cancelled = false;
  final stopped = Completer<void>();
  DownloadHandle<ResourceDownloadEvidence>? handle;
  PdfReaderController? controller;
  void check() {
    if (cancelled) throw const PdfFailure(PdfFailureCode.cancelled);
  }
}

/// Catalog-injected PDF pipeline. B07 retains the provenance/writer lease until
/// the new immutable final is proven, closed and promoted. No AI dependency.
class VerifiedLibraryActions implements LibraryBookActions {
  VerifiedLibraryActions({
    required Future<PdfLibraryStorage> Function() storage,
    required this.reader,
    required this.cleanup,
    required this.present,
  }) : _storage = storage;
  final Future<PdfLibraryStorage> Function() _storage;
  Future<PdfLibraryStorage>? _initializing;
  final PdfReaderPort reader;
  final ResourceCleanupOwner cleanup;
  final Future<void> Function(PdfReaderController, LibraryBook) present;
  final _operations = <String, _Operation>{};
  @override
  bool get supportsDownloads => reader.available;
  @override
  bool get supportsReading => reader.available;
  @override
  DownloadProgress? progress(LibraryBook book) => _downloadProgress(book);
  // DownloadService progress is sampled without asynchronous storage lookup.
  PdfLibraryStorage? _resolved;
  DownloadProgress? _downloadProgress(LibraryBook book) {
    final handle = _operations[book.id]?.handle;
    return handle == null ? null : _resolved?.downloads.progress(handle);
  }

  Future<PdfLibraryStorage> _getStorage() async =>
      _resolved ??= await (_initializing ??= _storage());

  @override
  Future<BookFileState> inspect(LibraryBook book) async {
    if (!reader.available) return BookFileState.readerRequired;
    final storage = await _getStorage();
    PdfBookLease? lease;
    PdfDocumentPort? document;
    try {
      lease = await storage.store.acquire(book.download);
      if (!await lease.hasVerifiedBook()) {
        return await lease.book.exists()
            ? BookFileState.invalid
            : BookFileState.missing;
      }
      document = await reader.open(lease.book);
      await document.render(0, width: 256);
      await document.close();
      document = null;
      return BookFileState.readable;
    } on PdfFailure catch (error) {
      return error.code == PdfFailureCode.unavailable
          ? BookFileState.readerRequired
          : BookFileState.invalid;
    } finally {
      if (lease != null) await _release(lease, document);
    }
  }

  Future<void> _release(
    PdfBookLease lease,
    PdfDocumentPort? document, [
    PdfReaderController? controller,
  ]) async {
    // The retry closure owns handles only; no Widget/context or rendered image.
    await cleanup.track(() async {
      if (controller != null) {
        await controller.close();
      } else {
        await document?.close();
      }
      await lease.release();
    });
  }

  Future<void> _run(
    LibraryBook book,
    Future<void> Function(_Operation, PdfLibraryStorage) run,
  ) async {
    PdfInstallStore.checkSpec(book.download);
    if (!reader.available) throw const PdfFailure(PdfFailureCode.unavailable);
    if (_operations.containsKey(book.id)) {
      throw const PdfFailure(PdfFailureCode.busy);
    }
    final operation = _Operation();
    _operations[book.id] = operation;
    try {
      final storage = await _getStorage();
      operation.check();
      await run(operation, storage);
    } finally {
      _operations.remove(book.id);
    }
  }

  @override
  Future<void> download(LibraryBook book) => _run(book, (op, storage) async {
    final lease = await storage.store.acquire(book.download);
    PdfDocumentPort? document;
    try {
      op.check();
      if (await lease.hasVerifiedBook()) return;
      Future<void> install() => storage.downloads.withCompletedArtifact(
        book.download,
        (source) async {
          op.check();
          final file = await lease.prepare(source);
          op.check();
          document = await reader.open(file);
          op.check();
          await document!.render(0, width: 256);
          op.check();
          await document!.close();
          document = null;
          op.check();
          await lease.promote();
        },
      );
      try {
        await install();
      } on DownloadFailure catch (e) {
        if (e.code != DownloadFailureCode.candidateUnavailable) rethrow;
        op.check();
        await storage.downloads.discardCorruptCompletedArtifact(book.download);
        op.check();
        op.handle = storage.downloads.start(book.download);
        final result = await op.handle!.result;
        op.check();
        if (result.state != DownloadState.downloaded) {
          throw result.failure ?? const PdfFailure(PdfFailureCode.cancelled);
        }
        await install();
      }
    } finally {
      await _release(lease, document);
    }
  });
  @override
  Future<void> open(LibraryBook book) => _run(book, (op, storage) async {
    final lease = await storage.store.acquire(book.download);
    PdfDocumentPort? document;
    PdfReaderController? controller;
    try {
      op.check();
      if (!await lease.hasVerifiedBook()) {
        throw const PdfFailure(PdfFailureCode.invalidFile);
      }
      op.check();
      document = await reader.open(lease.book);
      op.check();
      controller = PdfReaderController(document);
      op.controller = controller;
      await Future.any<void>([present(controller, book), op.stopped.future]);
      op.check();
      await controller.close();
    } finally {
      controller?.image = null;
      await _release(lease, document, controller);
      controller?.dispose();
    }
  });
  @override
  Future<void> cancel(LibraryBook book) async {
    final op = _operations[book.id];
    if (op == null) return;
    op.cancelled = true;
    if (!op.stopped.isCompleted) op.stopped.complete();
    final handle = op.handle;
    if (handle != null) await (await _getStorage()).downloads.cancel(handle);
    // Closing erases pixels immediately. The operation owner retains/retries
    // the file pin if native close fails; cancellation itself is idempotent.
    try {
      await op.controller?.close();
    } catch (_) {
      /* owner joins close */
    }
  }
}
