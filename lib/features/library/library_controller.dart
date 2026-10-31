import 'dart:async';
import 'package:flutter/foundation.dart';
import '../resources/download_contracts.dart';
import 'library_contracts.dart';
import 'pdf_reader_contracts.dart';

class LibraryController extends ChangeNotifier {
  LibraryController({
    ApprovedLibraryCatalog catalog = const UnavailableLibraryCatalog(),
    LibraryBookActions actions = const UnavailableLibraryActions(),
  }) : _catalog = catalog,
       _actions = actions;
  final ApprovedLibraryCatalog _catalog;
  final LibraryBookActions _actions;
  List<LibraryBook> _all = const [];
  final _states = <String, BookFileState>{};
  final _busy = <String, LibraryBook>{};
  String _query = '';
  String? category;
  bool loading = false, catalogAvailable = false, _closed = false;
  Object? failure;
  int _version = 0;
  Timer? _progress;
  List<LibraryBook> get books => List.unmodifiable(
    _all.where(
      (b) =>
          (category == null || b.categoryId == category) &&
          ('${b.arabicTitle} ${b.englishTitle} ${b.id}').toLowerCase().contains(
            _query,
          ),
    ),
  );
  List<LibraryBook> get categories => List.unmodifiable(
    {for (final book in _all) book.categoryId: book}.values,
  );
  BookFileState state(LibraryBook book) =>
      _states[book.id] ?? BookFileState.unverified;
  bool busy(LibraryBook book) => _busy.containsKey(book.id);
  bool canDownload(LibraryBook book) =>
      !_closed &&
      !loading &&
      _all.contains(book) &&
      _actions.supportsDownloads &&
      !busy(book) &&
      state(book) != BookFileState.readable;
  bool canOpen(LibraryBook book) =>
      !_closed &&
      !loading &&
      _all.contains(book) &&
      _actions.supportsReading &&
      !busy(book) &&
      state(book) == BookFileState.readable;
  DownloadProgress? progress(LibraryBook book) => _actions.progress(book);
  void setQuery(String text) {
    _query = text.trim().toLowerCase();
    _notify();
  }

  void setCategory(String? value) {
    category = categories.any((b) => b.categoryId == value) ? value : null;
    _notify();
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> load() async {
    final version = ++_version;
    loading = true;
    failure = null;
    _notify();
    try {
      final values = await _catalog.read();
      if (_closed || version != _version) return;
      if (values != null &&
          (values.length > 1000 ||
              values.any((b) => !b.isWellFormed) ||
              values.map((b) => b.id).toSet().length != values.length)) {
        throw const LibraryFailure(LibraryFailureCode.invalidCatalog);
      }
      final labels = <String, (String, String)>{};
      for (final book in values ?? <LibraryBook>[]) {
        final label = (book.categoryArabic, book.categoryEnglish);
        if (labels.containsKey(book.categoryId) &&
            labels[book.categoryId] != label) {
          throw const LibraryFailure(LibraryFailureCode.invalidCatalog);
        }
        labels[book.categoryId] = label;
      }
      _all = List.unmodifiable(values ?? const <LibraryBook>[]);
      catalogAvailable = values != null;
      category = null;
      _states.clear();
      for (final book in _all) {
        BookFileState value;
        try {
          value = await _actions.inspect(book);
        } catch (_) {
          value = BookFileState.unverified;
        }
        if (_closed || version != _version) return;
        // A missing reader must not turn byte presence into a clickable book.
        _states[book.id] =
            value == BookFileState.readable && !_actions.supportsReading
            ? BookFileState.readerRequired
            : value;
      }
    } catch (error) {
      if (!_closed && version == _version) {
        _all = const [];
        catalogAvailable = false;
        failure = error is LibraryFailure
            ? error
            : const LibraryFailure(LibraryFailureCode.catalogUnavailable);
      }
    } finally {
      if (!_closed && version == _version) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> download(LibraryBook book) async {
    if (canDownload(book)) await _run(book, () => _actions.download(book));
  }

  Future<void> open(LibraryBook book) async {
    if (!canOpen(book)) {
      failure = const LibraryFailure(LibraryFailureCode.readerUnavailable);
      _notify();
      return;
    }
    await _run(book, () => _actions.open(book));
  }

  Future<void> _run(LibraryBook book, Future<void> Function() action) async {
    final version = _version;
    _busy[book.id] = book;
    failure = null;
    _progress ??= Timer.periodic(
      const Duration(milliseconds: 150),
      (_) => _notify(),
    );
    _notify();
    try {
      await action();
      if (_closed || version != _version) return;
      final value = await _actions.inspect(book);
      if (!_closed && version == _version) {
        _states[book.id] =
            value == BookFileState.readable && !_actions.supportsReading
            ? BookFileState.readerRequired
            : value;
      }
    } catch (error) {
      if (!_closed && version == _version) {
        failure =
            error is LibraryFailure ||
                error is DownloadFailure ||
                error is PdfFailure
            ? error
            : const LibraryFailure(LibraryFailureCode.ioFailure);
      }
    } finally {
      _busy.remove(book.id);
      if (_busy.isEmpty) {
        _progress?.cancel();
        _progress = null;
      }
      _notify();
    }
  }

  Future<void> cancel(LibraryBook book) async {
    try {
      await _actions.cancel(book);
    } catch (_) {
      if (!_closed) {
        failure = const LibraryFailure(LibraryFailureCode.ioFailure);
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    _version++;
    _progress?.cancel();
    for (final book in _busy.values.toList()) {
      unawaited(cancel(book));
    }
    super.dispose();
  }
}
