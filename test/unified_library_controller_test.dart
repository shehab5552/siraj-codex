import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/library/library_controller.dart';
import 'package:siraj/features/library/library_contracts.dart';
import 'package:siraj/features/resources/download_contracts.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';

class _Catalog implements ApprovedLibraryCatalog {
  List<LibraryBook>? books;
  @override
  Future<List<LibraryBook>?> read() async => books;
}

class _Actions implements LibraryBookActions {
  @override
  bool get supportsDownloads => true;
  @override
  bool get supportsReading => false;
  final opened = <String>[];
  @override
  Future<BookFileState> inspect(LibraryBook book) async =>
      BookFileState.readerRequired;
  @override
  Future<void> download(LibraryBook book) async {}
  @override
  Future<void> open(LibraryBook book) async {
    opened.add(book.id);
  }

  @override
  Future<void> cancel(LibraryBook book) async {}
  @override
  DownloadProgress? progress(LibraryBook book) => null;
}

LibraryBook testBook(String id, String category) => LibraryBook(
  id: id,
  arabicTitle: 'كتاب اصطناعي $id',
  englishTitle: 'Synthetic $id',
  categoryId: category,
  categoryArabic: category,
  categoryEnglish: category,
  download: DownloadSpec(
    resourceId: id,
    artifactRevision: 'test-only',
    kind: ResourceContractKind.pdf,
    url: Uri.https('example.invalid', '/$id'),
    destinationKey: id,
    maxBytes: 1024,
    expectedSize: 10,
  ),
);
void main() {
  test('missing official catalog never supplies prototype books', () async {
    final c = LibraryController();
    await c.load();
    expect(c.catalogAvailable, isFalse);
    expect(c.books, isEmpty);
    c.dispose();
  });
  test('search and categories filter only trusted supplied metadata', () async {
    final catalog = _Catalog()
      ..books = [testBook('alpha', 'a'), testBook('beta', 'b')];
    final c = LibraryController(catalog: catalog, actions: _Actions());
    await c.load();
    expect(c.books.length, 2);
    c.setQuery('BETA');
    expect(c.books.single.id, 'beta');
    c.setCategory('a');
    expect(c.books, isEmpty);
    c.setQuery('');
    expect(c.books.single.id, 'alpha');
    c.dispose();
  });
  test('downloaded bytes without an approved reader cannot open', () async {
    final catalog = _Catalog()..books = [testBook('alpha', 'a')];
    final actions = _Actions();
    final c = LibraryController(catalog: catalog, actions: actions);
    await c.load();
    expect(c.canOpen(c.books.single), isFalse);
    await c.open(c.books.single);
    expect(actions.opened, isEmpty);
    c.dispose();
  });
}
