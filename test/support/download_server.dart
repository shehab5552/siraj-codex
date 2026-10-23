import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Isolated TLS server. The checked-in key is a public test fixture only.
class DownloadTestServer {
  DownloadTestServer._(this.server);
  final HttpServer server;
  final requests = <({String? range, String? ifRange})>[];
  late Future<void> Function(HttpRequest request, int index) respond;

  Uri get url => Uri.parse('https://127.0.0.1:${server.port}/artifact');

  static Future<DownloadTestServer> start() async {
    final context = SecurityContext()
      ..useCertificateChain('test/support/download_tls/server_cert.pem')
      ..usePrivateKey('test/support/download_tls/server_key.pem');
    final fixture = DownloadTestServer._(
      await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context),
    );
    fixture.server.listen((request) async {
      final index = fixture.requests.length;
      fixture.requests.add((
        range: request.headers.value(HttpHeaders.rangeHeader),
        ifRange: request.headers.value(HttpHeaders.ifRangeHeader),
      ));
      try {
        await fixture.respond(request, index);
      } on IOException {
        // Cancellation deliberately disconnects a live response.
      }
    });
    return fixture;
  }

  HttpClient client() {
    final context = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates('test/support/download_tls/server_cert.pem');
    return HttpClient(context: context);
  }

  Future<void> close() => server.close(force: true);

  static Future<void> full(
    HttpRequest request,
    List<int> bytes, {
    String? etag = '"one"',
  }) async {
    request.response.contentLength = bytes.length;
    if (etag != null) {
      request.response.headers.set(HttpHeaders.etagHeader, etag);
    }
    request.response.add(bytes);
    await request.response.close();
  }

  static Future<void> interrupt(
    HttpRequest request,
    List<int> bytes, {
    String? etag = '"one"',
  }) async {
    // Detach before HttpResponse sends headers, then deliberately terminate a
    // raw HTTP body short of its declared Content-Length over the TLS socket.
    final socket = await request.response.detachSocket(writeHeaders: false);
    socket.add(
      ascii.encode(
        'HTTP/1.1 200 OK\r\nContent-Length: ${bytes.length}\r\n${etag == null ? '' : 'ETag: $etag\r\n'}Connection: close\r\n\r\n',
      ),
    );
    socket.add(bytes.sublist(0, bytes.length ~/ 2));
    await socket.flush();
    await socket.close();
  }

  static Future<void> range(
    HttpRequest request,
    List<int> bytes, {
    String etag = '"one"',
    String? contentRange,
  }) async {
    final offset = int.parse(
      request.headers
          .value(HttpHeaders.rangeHeader)!
          .replaceAll(RegExp(r'[^0-9]'), ''),
    );
    request.response.statusCode = HttpStatus.partialContent;
    request.response.contentLength = bytes.length - offset;
    request.response.headers.set(HttpHeaders.etagHeader, etag);
    request.response.headers.set(
      HttpHeaders.contentRangeHeader,
      contentRange ?? 'bytes $offset-${bytes.length - 1}/${bytes.length}',
    );
    request.response.add(bytes.sublist(offset));
    await request.response.close();
  }
}
