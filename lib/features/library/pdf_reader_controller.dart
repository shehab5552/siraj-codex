import 'package:flutter/foundation.dart';
import 'pdf_reader_contracts.dart';

/// One render in flight, one coalesced requested page, no stale pixels.
class PdfReaderController extends ChangeNotifier {
  PdfReaderController(this._document);
  final PdfDocumentPort _document;
  int get pageCount => _document.pageCount;
  int page = 0;
  int _width = 900, _generation = 0;
  bool closed = false, _disposed = false, _nativeClosed = false;
  PdfPageImage? image;
  PdfFailure? failure;
  Future<void>? _job, _closing;
  bool get loading => _job != null;
  Future<void> get idle => _job ?? Future<void>.value();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void showPage(int target, {int width = 900}) {
    if (closed) return;
    if (target < 0 || target >= pageCount || width < 1 || width > 2048) {
      failure = const PdfFailure(PdfFailureCode.invalidPage);
      _notify();
      return;
    }
    page = target;
    _width = width;
    _generation++;
    image = null;
    failure = null;
    _job ??= _renderLoop();
    _notify();
  }

  Future<void> _renderLoop() async {
    // Ensure _job is assigned before synchronous fake/port failures finish.
    await Future<void>.value();
    try {
      while (!closed) {
        final version = _generation, target = page, width = _width;
        try {
          final value = await _document.render(target, width: width);
          if (!closed && version == _generation) {
            if (value.documentId != _document.id ||
                value.page != target ||
                value.width != width) {
              throw const PdfFailure(PdfFailureCode.invalidFile);
            }
            image = value;
          }
        } catch (error) {
          if (!closed && version == _generation) {
            failure = error is PdfFailure
                ? error
                : const PdfFailure(PdfFailureCode.ioFailure);
          }
        }
        if (version == _generation || closed) break;
      }
    } finally {
      _job = null;
      _notify();
    }
  }

  void retry() => showPage(page, width: _width);
  Future<void> close() {
    closed = true;
    image = null;
    _generation++;
    _notify();
    return _closing ??= _close().whenComplete(() => _closing = null);
  }

  Future<void> _close() async {
    await idle;
    if (!_nativeClosed) {
      await _document.close();
      _nativeClosed = true;
    }
  }

  @override
  void dispose() {
    // The owner, not this view, awaits close and retains the file lease.
    _disposed = true;
    image = null;
    super.dispose();
  }
}
