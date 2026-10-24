import '../../features/resources/download_contracts.dart';
import '../../features/resources/resource_validation_contracts.dart';

enum BookFileState { missing, unverified, readerRequired, readable, invalid }

enum LibraryFailureCode {
  catalogUnavailable,
  invalidCatalog,
  readerUnavailable,
  fileUnavailable,
  ioFailure,
}

class LibraryFailure implements Exception {
  const LibraryFailure(this.code);
  final LibraryFailureCode code;
}

class LibraryBook {
  const LibraryBook({
    required this.id,
    required this.arabicTitle,
    required this.englishTitle,
    required this.categoryId,
    required this.categoryArabic,
    required this.categoryEnglish,
    required this.download,
  });
  final String id,
      arabicTitle,
      englishTitle,
      categoryId,
      categoryArabic,
      categoryEnglish;

  /// Trusted catalog transport identity, independent of LLM/RAG resources.
  final DownloadSpec download;
  bool get isWellFormed =>
      [
        id,
        arabicTitle,
        englishTitle,
        categoryId,
        categoryArabic,
        categoryEnglish,
      ].every(
        (s) =>
            s.trim().isNotEmpty &&
            s == s.trim() &&
            s.length <= 1024 &&
            !RegExp(r'[\x00-\x1f]').hasMatch(s),
      ) &&
      download.kind == ResourceContractKind.pdf;
}

abstract interface class ApprovedLibraryCatalog {
  Future<List<LibraryBook>?> read();
}

class UnavailableLibraryCatalog implements ApprovedLibraryCatalog {
  const UnavailableLibraryCatalog();
  @override
  Future<List<LibraryBook>?> read() async => null;
}

/// The implementation reuses B07 transport and a verified app-private PDF
/// reader. `readable` requires actual parser/reader proof, never a SQL READY row
/// or a recognized %PDF header. open completes only when the reader closes.
abstract interface class LibraryBookActions {
  bool get supportsDownloads;
  bool get supportsReading;
  Future<BookFileState> inspect(LibraryBook book);
  Future<void> download(LibraryBook book);
  Future<void> open(LibraryBook book);
  Future<void> cancel(LibraryBook book);
  DownloadProgress? progress(LibraryBook book);
}

class UnavailableLibraryActions implements LibraryBookActions {
  const UnavailableLibraryActions();
  @override
  bool get supportsDownloads => false;
  @override
  bool get supportsReading => false;
  @override
  Future<BookFileState> inspect(LibraryBook book) async =>
      BookFileState.unverified;
  @override
  Future<void> download(LibraryBook book) async =>
      throw const LibraryFailure(LibraryFailureCode.fileUnavailable);
  @override
  Future<void> open(LibraryBook book) async =>
      throw const LibraryFailure(LibraryFailureCode.readerUnavailable);
  @override
  Future<void> cancel(LibraryBook book) async {}
  @override
  DownloadProgress? progress(LibraryBook book) => null;
}

class LibraryIntegration {
  const LibraryIntegration({
    this.catalog = const UnavailableLibraryCatalog(),
    this.actions = const UnavailableLibraryActions(),
  });
  final ApprovedLibraryCatalog catalog;
  final LibraryBookActions actions;
}
