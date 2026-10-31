import 'dart:io';
import 'dart:typed_data';

enum PdfFailureCode {
  unavailable,
  missingFile,
  unsafePath,
  invalidFile,
  busy,
  closed,
  invalidPage,
  resourceLimit,
  ioFailure,
  cancelled,
  sessionExpired,
}

class PdfFailure implements Exception {
  const PdfFailure(this.code);
  final PdfFailureCode code;
}

abstract interface class PdfReaderPort {
  bool get available;
  Future<PdfDocumentPort> open(File file);
}

/// Owned native handle. close completes only after pages and the descriptor
/// close. On close failure the owner must retain the installed-file lease.
abstract interface class PdfDocumentPort {
  String get id;
  int get pageCount;
  Future<PdfPageImage> render(int page, {required int width});
  Future<void> close();
}

class PdfPageImage {
  PdfPageImage({
    required this.documentId,
    required this.page,
    required this.width,
    required this.height,
    required Uint8List png,
  }) : png = Uint8List.fromList(png).asUnmodifiableView();
  final String documentId;
  final int page, width, height;
  final Uint8List png;
}
