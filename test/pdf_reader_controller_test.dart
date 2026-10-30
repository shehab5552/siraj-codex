import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/library/pdf_reader_contracts.dart';
import 'package:siraj/features/library/pdf_reader_controller.dart';

class Document implements PdfDocumentPort {
  @override
  final String id = 'test-document';
  @override
  final int pageCount = 3;
  final calls = <(int, int)>[];
  final jobs = <Completer<PdfPageImage>>[];
  int closes = 0;
  bool failClose = false;
  @override
  Future<PdfPageImage> render(int page, {required int width}) {
    calls.add((page, width));
    final job = Completer<PdfPageImage>();
    jobs.add(job);
    return job.future;
  }

  void complete(int index) => jobs[index].complete(
    PdfPageImage(
      documentId: id,
      page: calls[index].$1,
      width: calls[index].$2,
      height: 400,
      png: Uint8List.fromList([index + 1]),
    ),
  );
  @override
  Future<void> close() async {
    closes++;
    if (failClose) throw const PdfFailure(PdfFailureCode.ioFailure);
  }
}

void main() {
  test(
    'serial render coalesces navigation and hides stale page immediately',
    () async {
      final doc = Document();
      final c = PdfReaderController(doc);
      c.showPage(0);
      await Future<void>.delayed(Duration.zero);
      c.showPage(1);
      c.showPage(2);
      expect(doc.calls, [(0, 900)]);
      expect(c.image, isNull);
      doc.complete(0);
      await Future<void>.delayed(Duration.zero);
      expect(doc.calls, [(0, 900), (2, 900)]);
      expect(c.image, isNull);
      doc.complete(1);
      await c.idle;
      expect(c.image!.page, 2);
      c.showPage(1);
      await Future<void>.delayed(Duration.zero);
      expect(c.image, isNull);
      doc.complete(2);
      await c.idle;
      await c.close();
      c.dispose();
    },
  );
  test(
    'close drains rendering; no late pixels; failed close can be retried',
    () async {
      final doc = Document()..failClose = true;
      final c = PdfReaderController(doc)..showPage(0);
      await Future<void>.delayed(Duration.zero);
      final closed = expectLater(c.close(), throwsA(isA<PdfFailure>()));
      expect(c.closed, isTrue);
      expect(doc.closes, 0);
      doc.complete(0);
      await closed;
      expect(c.image, isNull);
      expect(doc.closes, 1);
      doc.failClose = false;
      await c.close();
      expect(doc.closes, 2);
      c.showPage(2);
      expect(doc.calls, hasLength(1));
      c.dispose();
    },
  );
  test('typed render failure, retry, and page bounds', () async {
    final doc = Document();
    final c = PdfReaderController(doc)..showPage(9);
    expect(c.failure!.code, PdfFailureCode.invalidPage);
    expect(doc.calls, isEmpty);
    c.showPage(1);
    await Future<void>.delayed(Duration.zero);
    doc.jobs[0].completeError(const PdfFailure(PdfFailureCode.resourceLimit));
    await c.idle;
    expect(c.failure!.code, PdfFailureCode.resourceLimit);
    c.retry();
    await Future<void>.delayed(Duration.zero);
    doc.complete(1);
    await c.idle;
    expect(c.image!.page, 1);
    expect(c.failure, isNull);
    await c.close();
    c.dispose();
  });
}
