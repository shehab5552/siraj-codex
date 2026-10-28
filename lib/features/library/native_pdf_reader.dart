import 'dart:io';
import 'package:flutter/services.dart';
import 'pdf_reader_contracts.dart';

/// Android's built-in PdfRenderer. No plugin engine, network, external intent,
/// model resource, or fake document is selected here.
class NativePdfReader implements PdfReaderPort {
  const NativePdfReader();
  static const _channel = MethodChannel('siraj/pdf');
  @override
  bool get available => Platform.isAndroid;
  static Future<Directory> appSupport() async {
    final path = await _invoke<String>('appSupport');
    if (path == null || !path.startsWith('/') || path.contains('\x00')) {
      throw const PdfFailure(PdfFailureCode.unavailable);
    }
    return Directory(path);
  }

  @override
  Future<PdfDocumentPort> open(File file) async {
    final reply = await _invoke<Map>('open', {'path': file.absolute.path});
    final id = reply?['id'], pages = reply?['pages'];
    if (id is! String ||
        id.isEmpty ||
        id.length > 128 ||
        pages is! int ||
        pages < 1 ||
        pages > 100000) {
      if (id is String && id.isNotEmpty && id.length <= 128) {
        await _invoke<void>('close', {'id': id});
      }
      throw const PdfFailure(PdfFailureCode.invalidFile);
    }
    return _NativeDocument(id, pages);
  }

  static Future<T?> _invoke<T>(
    String method, [
    Map<String, Object>? args,
  ]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      throw const PdfFailure(PdfFailureCode.unavailable);
    } on PlatformException catch (e) {
      throw PdfFailure(switch (e.code) {
        'unsafe_path' => PdfFailureCode.unsafePath,
        'missing_file' => PdfFailureCode.missingFile,
        'invalid_file' => PdfFailureCode.invalidFile,
        'invalid_page' => PdfFailureCode.invalidPage,
        'resource_limit' => PdfFailureCode.resourceLimit,
        'busy' => PdfFailureCode.busy,
        'closed' => PdfFailureCode.closed,
        _ => PdfFailureCode.ioFailure,
      });
    }
  }
}

class _NativeDocument implements PdfDocumentPort {
  _NativeDocument(this.id, this.pageCount);
  @override
  final String id;
  @override
  final int pageCount;
  bool _closed = false;
  Future<void>? _closing;
  @override
  Future<PdfPageImage> render(int page, {required int width}) async {
    if (_closed || _closing != null) {
      throw const PdfFailure(PdfFailureCode.closed);
    }
    if (page < 0 || page >= pageCount || width < 1 || width > 2048) {
      throw const PdfFailure(PdfFailureCode.invalidPage);
    }
    final reply = await NativePdfReader._invoke<Map>('render', {
      'id': id,
      'page': page,
      'width': width,
    });
    final height = reply?['height'], png = reply?['png'];
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (reply?['id'] != id ||
        reply?['page'] != page ||
        reply?['width'] != width ||
        height is! int ||
        height < 1 ||
        height > 4096 ||
        width * height > 4 * 1024 * 1024 ||
        png is! Uint8List ||
        png.length < 8 ||
        png.length > 20 * 1024 * 1024 ||
        List.generate(8, (i) => png[i]).join(',') != signature.join(',')) {
      throw const PdfFailure(PdfFailureCode.invalidFile);
    }
    if (_closed || _closing != null) {
      throw const PdfFailure(PdfFailureCode.closed);
    }
    return PdfPageImage(
      documentId: id,
      page: page,
      width: width,
      height: height,
      png: png,
    );
  }

  @override
  Future<void> close() {
    if (_closed) return Future<void>.value();
    return _closing ??= NativePdfReader._invoke<void>('close', {
      'id': id,
    }).then<void>((_) => _closed = true).whenComplete(() => _closing = null);
  }
}
