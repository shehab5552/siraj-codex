import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/resources/download_contracts.dart';
import 'package:siraj/features/resources/download_service.dart';
import 'package:siraj/features/resources/resource_download_validator.dart';
import 'package:siraj/features/resources/resource_format_preflight.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';

import 'support/download_server.dart';

class TestSpace implements DownloadSpaceProbe {
  int bytes = 1024 * 1024 * 1024;
  bool unavailable = false;
  int Function(Directory)? reading;
  @override
  Future<int> availableBytes(Directory directory) async {
    if (unavailable) throw const FileSystemException('space probe unavailable');
    return reading?.call(directory) ?? bytes;
  }
}

extension FixtureSpec on DownloadSpec {
  DownloadSpec copyWith({
    String? artifactRevision,
    Uri? url,
    String? destinationKey,
    int? expectedSize,
  }) => DownloadSpec(
    resourceId: resourceId,
    artifactRevision: artifactRevision ?? this.artifactRevision,
    kind: kind,
    url: url ?? this.url,
    destinationKey: destinationKey ?? this.destinationKey,
    expectedSize: expectedSize ?? this.expectedSize,
    expectedSha256: expectedSha256,
    maxBytes: maxBytes,
  );
}

class BlockingValidator
    implements StagedDownloadValidator<ResourceDownloadEvidence> {
  final entered = Completer<void>();
  final release = Completer<void>();
  bool reject = false;
  @override
  void checkSpec(DownloadSpec spec) =>
      const ResourceDownloadValidator().checkSpec(spec);
  @override
  Future<ResourceDownloadEvidence> validate(
    Directory directory,
    DownloadSpec spec,
  ) async {
    entered.complete();
    await release.future;
    if (reject) {
      throw const DownloadFailure(DownloadFailureCode.integrityFailure);
    }
    return const ResourceDownloadValidator().validate(directory, spec);
  }
}

class AfterValidation extends ResourceDownloadValidator {
  AfterValidation(this.callback);
  final void Function() callback;
  @override
  Future<ResourceDownloadEvidence> validate(
    Directory directory,
    DownloadSpec spec,
  ) async {
    final evidence = await super.validate(directory, spec);
    Timer.run(callback);
    return evidence;
  }
}

void main() {
  late Directory support;
  late DownloadTestServer server;
  late TestSpace space;
  late DownloadService<ResourceDownloadEvidence> service;
  late List<int> payload;
  late DownloadSpec spec;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('siraj-download-');
    server = await DownloadTestServer.start();
    space = TestSpace();
    payload = [
      ...ascii.encode('%PDF-1.7\n'),
      ...List<int>.generate(128 * 1024, (i) => i % 251),
    ];
    final hash = await Sha256().hash(payload);
    spec = DownloadSpec(
      resourceId: 'isolated-book',
      artifactRevision: 'fixture-1',
      kind: ResourceContractKind.pdf,
      url: server.url,
      destinationKey: 'book',
      expectedSize: payload.length,
      expectedSha256: hash.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
      maxBytes: payload.length + 1024,
    );
    service = DownloadService(
      appSupportDirectory: support,
      spaceProbe: space,
      validator: const ResourceDownloadValidator(),
      clientFactory: server.client,
      timeout: const Duration(seconds: 3),
    );
    server.respond = (request, _) => DownloadTestServer.full(request, payload);
  });
  tearDown(() async {
    await server.close();
    await support.delete(recursive: true);
  });

  File getMetadata() =>
      File('${support.path}/downloads-staging-v1/book/provenance.json');
  File getPartial() =>
      File('${support.path}/downloads-staging-v1/book/payload.part');

  Future<DownloadHandle<ResourceDownloadEvidence>> interrupted() async {
    server.respond = (request, _) =>
        DownloadTestServer.interrupt(request, payload);
    final handle = service.start(spec);
    final result = await handle.result;
    expect(result.state, DownloadState.failed);
    expect(result.failure!.code, DownloadFailureCode.networkFailure);
    expect(await getPartial().length(), greaterThan(0));
    return handle;
  }

  test(
    'HTTPS download integrates integrity and header evidence without READY',
    () async {
      final result = await service.start(spec).result;
      expect(result.state, DownloadState.downloaded);
      expect(await result.stagedFile!.readAsBytes(), payload);
      expect(result.evidence!.integrity.sha256Matched, isTrue);
      expect(
        result.evidence!.format.remainingChecks,
        contains(ResourceValidationCheck.pdfReadable),
      );
      expect(
        DownloadState.values.map((state) => state.name),
        isNot(contains(anyOf('ready', 'active'))),
      );
    },
  );

  test(
    'new service instance resumes interrupted bytes with strong ETag and Range',
    () async {
      await interrupted();
      final length = await getPartial().length();
      service = DownloadService(
        appSupportDirectory: support,
        spaceProbe: space,
        validator: const ResourceDownloadValidator(),
        clientFactory: server.client,
      );
      server.respond = (request, _) =>
          DownloadTestServer.range(request, payload);
      final result = await service.start(spec).result;
      expect(result.state, DownloadState.downloaded);
      expect(result.resumedFrom, length);
      expect(server.requests.last, (range: 'bytes=$length-', ifRange: '"one"'));
      expect(await result.stagedFile!.readAsBytes(), payload);
    },
  );

  test(
    'server ignoring Range with 200 replaces only its own staging bytes',
    () async {
      final handle = await interrupted();
      server.respond = (request, _) =>
          DownloadTestServer.full(request, payload);
      final result = await service.retry(handle);
      expect(result.state, DownloadState.downloaded);
      expect(result.restartReason, DownloadRestartReason.rangeIgnored);
      expect(result.resumedFrom, 0);
      expect(await result.stagedFile!.readAsBytes(), payload);
    },
  );

  test('invalid Content-Range never appends response bytes', () async {
    final handle = await interrupted();
    final before = await getPartial().readAsBytes();
    server.respond = (request, _) =>
        DownloadTestServer.range(request, payload, contentRange: 'bytes 0-3/4');
    final result = await service.retry(handle);
    expect(result.failure!.code, DownloadFailureCode.invalidRange);
    expect(await getPartial().readAsBytes(), before);
  });

  test(
    'changed ETag in 206 triggers a clean GET instead of concatenation',
    () async {
      final handle = await interrupted();
      server.respond = (request, _) =>
          request.headers.value(HttpHeaders.rangeHeader) != null
          ? DownloadTestServer.range(request, payload, etag: '"two"')
          : DownloadTestServer.full(request, payload, etag: '"two"');
      final result = await service.retry(handle);
      expect(result.state, DownloadState.downloaded);
      expect(server.requests.last.range, isNull);
      expect(result.restartReason, DownloadRestartReason.validatorChanged);
      expect(result.resumedFrom, 0);
      expect(await result.stagedFile!.readAsBytes(), payload);
    },
  );

  for (final mode in [
    'json',
    'utf8',
    'large',
    'identity',
    'partial',
    'partialSameSize',
    'missing',
  ]) {
    test('untrusted $mode provenance forces zero-offset restart', () async {
      final handle = await interrupted();
      switch (mode) {
        case 'json':
          await getMetadata().writeAsString('{broken');
        case 'utf8':
          await getMetadata().writeAsBytes([0xff, 0xfe, 0xc0]);
        case 'large':
          await getMetadata().writeAsBytes(List.filled(128 * 1024, 32));
        case 'identity':
          final data =
              jsonDecode(await getMetadata().readAsString())
                  as Map<String, dynamic>;
          data['identity'] = '0' * 64;
          await getMetadata().writeAsString(jsonEncode(data));
        case 'partial':
          final file = await getPartial().open(mode: FileMode.writeOnlyAppend);
          await file.writeByte(0);
          await file.close();
        case 'partialSameSize':
          final bytes = await getPartial().readAsBytes();
          bytes[0] ^= 1;
          await getPartial().writeAsBytes(bytes);
        case 'missing':
          await getMetadata().delete();
      }
      server.respond = (request, _) =>
          DownloadTestServer.full(request, payload);
      final result = await service.retry(handle);
      expect(result.state, DownloadState.downloaded);
      expect(server.requests.last.range, isNull);
      expect(result.restartReason, DownloadRestartReason.untrustedProvenance);
      expect(await result.stagedFile!.readAsBytes(), payload);
    });
  }

  test('different requested revision cannot resume an old partial', () async {
    await interrupted();
    final changed = spec.copyWith(artifactRevision: 'fixture-2');
    server.respond = (request, _) => DownloadTestServer.full(request, payload);
    final result = await service.start(changed).result;
    expect(result.state, DownloadState.downloaded);
    expect(server.requests.last.range, isNull);
    expect(result.restartReason, DownloadRestartReason.untrustedProvenance);
  });

  test('absent or weak ETag restarts safely', () async {
    server.respond = (request, _) =>
        DownloadTestServer.interrupt(request, payload, etag: 'W/"weak"');
    final handle = service.start(spec);
    await handle.result;
    server.respond = (request, _) => DownloadTestServer.full(request, payload);
    expect((await service.retry(handle)).state, DownloadState.downloaded);
    expect(server.requests.last.range, isNull);
  });

  test(
    'incorrect catalog size is rejected before any body is staged',
    () async {
      final result = await service
          .start(spec.copyWith(expectedSize: payload.length + 1))
          .result;
      expect(result.failure!.code, DownloadFailureCode.sizeMismatch);
    },
  );

  test(
    'same-size corrupted payload fails SHA without returning a staged candidate',
    () async {
      final corrupt = [...payload]..[payload.length - 1] ^= 1;
      server.respond = (request, _) =>
          DownloadTestServer.full(request, corrupt);
      final result = await service.start(spec).result;
      expect(result.failure!.code, DownloadFailureCode.integrityFailure);
      expect(result.evidence, isNull);
      expect(result.stagedFile, isNull);
    },
  );

  test('low disk space is typed and blocks payload writes', () async {
    space.bytes = 1;
    final result = await service.start(spec).result;
    expect(result.failure!.code, DownloadFailureCode.insufficientStorage);
    expect(await getPartial().exists(), isFalse);
  });

  test('space probe error fails closed', () async {
    space.unavailable = true;
    final result = await service.start(spec).result;
    expect(result.failure!.code, DownloadFailureCode.storageUnavailable);
  });

  test('read-only staging reports a real filesystem error', () async {
    await Directory('${support.path}/downloads-staging-v1').create();
    await Process.run('chmod', ['500', '${support.path}/downloads-staging-v1']);
    try {
      final result = await service.start(spec).result;
      expect(result.failure!.code, DownloadFailureCode.ioFailure);
    } finally {
      await Process.run('chmod', [
        '700',
        '${support.path}/downloads-staging-v1',
      ]);
    }
  });

  test('rejects traversal keys and HTTP before contacting server', () async {
    for (final key in ['../active', '/active', 'a/b', 'a\\b', '.', '']) {
      expect(
        (await service.start(spec.copyWith(destinationKey: key)).result)
            .failure!
            .code,
        DownloadFailureCode.invalidSpec,
      );
    }
    expect(
      (await service
              .start(spec.copyWith(url: spec.url.replace(scheme: 'http')))
              .result)
          .failure!
          .code,
      DownloadFailureCode.invalidSpec,
    );
    expect(server.requests, isEmpty);
  });

  test('symlink staging root never touches the external target', () async {
    final other = await Directory.systemTemp.createTemp('siraj-active-');
    try {
      final marker = File('${other.path}/active-model')
        ..writeAsStringSync('keep');
      await Link('${support.path}/downloads-staging-v1').create(other.path);
      expect(
        (await service.start(spec).result).failure!.code,
        DownloadFailureCode.unsafePath,
      );
      expect(await marker.readAsString(), 'keep');
    } finally {
      await other.delete(recursive: true);
    }
  });

  test(
    'cancel closes a live transfer, discards only owned staging and restarts safely',
    () async {
      final sent = Completer<void>();
      server.respond = (request, _) async {
        request.response.contentLength = payload.length;
        request.response.headers.set(HttpHeaders.etagHeader, '"one"');
        request.response.add(payload.sublist(0, 1024));
        await request.response.flush();
        sent.complete();
      };
      final handle = service.start(spec);
      await sent.future;
      final result = await service.cancel(handle);
      expect(result.state, DownloadState.cancelled);
      expect(await getPartial().exists(), isFalse);
      server.respond = (request, _) =>
          DownloadTestServer.full(request, payload);
      expect(
        (await service.resumeOrRestart(handle)).state,
        DownloadState.downloaded,
      );
      expect(server.requests.last.range, isNull);
    },
  );

  test('HTTP errors expose hostname and exact HTTP status for retry', () async {
    server.respond = (request, _) async {
      request.response.statusCode = 503;
      await request.response.close();
    };
    final handle = service.start(spec);
    final failed = await handle.result;
    expect(failed.failure!.code, DownloadFailureCode.httpFailure);
    expect(failed.failure!.httpStatus, 503);
    expect(failed.failure!.hostname, '127.0.0.1');
    server.respond = (request, _) => DownloadTestServer.full(request, payload);
    expect((await service.retry(handle)).state, DownloadState.downloaded);
  });

  test(
    'a completed candidate is never overwritten by another requested identity',
    () async {
      final first = await service.start(spec).result;
      final data = await first.stagedFile!.readAsBytes();
      final result = await service
          .start(spec.copyWith(artifactRevision: 'other'))
          .result;
      expect(result.failure?.code, DownloadFailureCode.candidateExists);
      expect(await first.stagedFile!.readAsBytes(), data);
      expect(server.requests.length, 1);
    },
  );

  test('chunked 206 cannot exceed the advertised range end', () async {
    final handle = await interrupted();
    final before = await getPartial().readAsBytes();
    server.respond = (request, _) async {
      final offset = before.length;
      request.response.statusCode = 206;
      request.response.headers.set(HttpHeaders.etagHeader, '"one"');
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $offset-${offset + 3}/${payload.length}',
      );
      request.response.add(payload.sublist(offset));
      await request.response.close();
    };
    final result = await service.retry(handle);
    expect(result.failure?.code, DownloadFailureCode.invalidRange);
    expect(await getPartial().readAsBytes(), before);
  });

  test('pause persists a checkpoint then resumes the paused handle', () async {
    server.respond = (request, _) async {
      request.response.bufferOutput = false;
      request.response.contentLength = payload.length;
      request.response.headers.set(HttpHeaders.etagHeader, '"one"');
      request.response.add(payload.sublist(0, 1024));
      await request.response.flush();
    };
    final handle = service.start(spec);
    await Future.doWhile(() async {
      if (service.progress(handle).downloadedBytes > 0) return false;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return true;
    }).timeout(const Duration(seconds: 2));
    expect((await service.pause(handle)).state, DownloadState.paused);
    final length = await getPartial().length();
    expect(length, 1024);
    server.respond = (request, _) => DownloadTestServer.range(request, payload);
    final result = await service.resumeOrRestart(handle);
    expect(result.state, DownloadState.downloaded);
    expect(result.resumedFrom, length);
  });

  test(
    'verification holds the writer lease and cancellation waits before cleanup',
    () async {
      final validator = BlockingValidator();
      service = DownloadService(
        appSupportDirectory: support,
        spaceProbe: space,
        validator: validator,
        clientFactory: server.client,
      );
      final handle = service.start(spec);
      await validator.entered.future;
      expect(service.progress(handle).state, DownloadState.verifying);
      final contender = DownloadService(
        appSupportDirectory: support,
        spaceProbe: space,
        validator: const ResourceDownloadValidator(),
        clientFactory: server.client,
      );
      final waiting = contender.start(spec);
      expect((await waiting.result).failure!.code, DownloadFailureCode.busy);
      expect(contender.progress(waiting).state, DownloadState.failed);
      expect(
        (await service.retry(handle)).failure!.code,
        DownloadFailureCode.busy,
      );
      expect(service.progress(handle).state, DownloadState.verifying);
      final cancelled = service.cancel(handle);
      expect(await getPartial().length(), payload.length);
      validator.release.complete();
      expect((await cancelled).state, DownloadState.cancelled);
      expect(await getPartial().exists(), isFalse);
      expect(server.requests.length, 1);
    },
  );

  test(
    'disk exhaustion during transfer returns no validation evidence',
    () async {
      space.reading = (directory) =>
          getPartial().existsSync() && getPartial().lengthSync() > 0
          ? 0
          : 1024 * 1024;
      final result = await service.start(spec).result;
      expect(result.failure!.code, DownloadFailureCode.insufficientStorage);
      expect(result.evidence, isNull);
      expect(result.stagedFile, isNull);
    },
  );

  test('default TLS refuses an untrusted server certificate', () async {
    service = DownloadService(
      appSupportDirectory: support,
      spaceProbe: space,
      validator: const ResourceDownloadValidator(),
    );
    final result = await service.start(spec).result;
    expect(result.failure!.code, DownloadFailureCode.networkFailure);
    expect(result.failure!.detail, contains('HandshakeException'));
    expect(server.requests, isEmpty);
  });

  test(
    'HTTPS redirects are not followed into another resource or cleartext',
    () async {
      server.respond = (request, _) async {
        request.response.statusCode = 302;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          spec.url.replace(scheme: 'http').toString(),
        );
        await request.response.close();
      };
      final result = await service.start(spec).result;
      expect(result.failure!.httpStatus, 302);
      expect(server.requests.length, 1);
    },
  );

  test(
    'content encoding cannot change byte offsets or checksum semantics',
    () async {
      server.respond = (request, _) async {
        request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
        await DownloadTestServer.full(request, payload);
      };
      expect(
        (await service.start(spec).result).failure!.code,
        DownloadFailureCode.protocolFailure,
      );
    },
  );

  test('416 on a partial triggers a fresh full request', () async {
    final handle = await interrupted();
    server.respond = (request, _) async {
      if (request.headers.value(HttpHeaders.rangeHeader) != null) {
        request.response.statusCode = 416;
        await request.response.close();
      } else {
        await DownloadTestServer.full(request, payload);
      }
    };
    final result = await service.retry(handle);
    expect(result.state, DownloadState.downloaded);
    expect(result.restartReason, DownloadRestartReason.rangeNotSatisfiable);
    expect(result.resumedFrom, 0);
    expect(server.requests.last.range, isNull);
  });

  for (final range in [
    'nonsense',
    'bytes 0-1/*',
    'bytes 1-0/2',
    'bytes -1-1/2',
    'bytes 0-999999999999999999999999/2',
  ]) {
    test('malformed Content-Range is rejected: $range', () async {
      final handle = await interrupted();
      final before = await getPartial().readAsBytes();
      server.respond = (request, _) =>
          DownloadTestServer.range(request, payload, contentRange: range);
      expect(
        (await service.retry(handle)).failure!.code,
        DownloadFailureCode.invalidRange,
      );
      expect(await getPartial().readAsBytes(), before);
    });
  }

  test(
    'payload symlink cannot read, overwrite or delete an active resource',
    () async {
      await Directory(
        '${support.path}/downloads-staging-v1/book',
      ).create(recursive: true);
      final active = File('${support.path}/active-model')
        ..writeAsStringSync('keep');
      await Link(getPartial().path).create(active.path);
      final result = await service.start(spec).result;
      expect(result.failure!.code, DownloadFailureCode.unsafePath);
      expect(await active.readAsString(), 'keep');
      expect(server.requests, isEmpty);
    },
  );

  test('a matching byte hash with invalid PDF header is rejected', () async {
    final invalid = List<int>.filled(payload.length, 0);
    final hash = await Sha256().hash(invalid);
    final requestSpec = DownloadSpec(
      resourceId: spec.resourceId,
      artifactRevision: spec.artifactRevision,
      kind: spec.kind,
      url: spec.url,
      destinationKey: spec.destinationKey,
      maxBytes: spec.maxBytes,
      expectedSize: invalid.length,
      expectedSha256: hash.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
    );
    server.respond = (request, _) => DownloadTestServer.full(request, invalid);
    final result = await service.start(requestSpec).result;
    expect(result.failure!.code, DownloadFailureCode.formatRejected);
    expect(result.stagedFile, isNull);
  });

  test(
    'cancel during the final durable checkpoint is honored before handoff',
    () async {
      late DownloadHandle<ResourceDownloadEvidence> handle;
      late Future<DownloadResult<ResourceDownloadEvidence>> cancellation;
      final requested = Completer<void>();
      service = DownloadService(
        appSupportDirectory: support,
        spaceProbe: space,
        clientFactory: server.client,
        validator: AfterValidation(() {
          cancellation = service.cancel(handle);
          requested.complete();
        }),
      );
      handle = service.start(spec);
      await requested.future;
      expect((await cancellation).state, DownloadState.cancelled);
      expect(await getPartial().exists(), isFalse);
    },
  );

  test(
    'two cancellations during paused finalization join one cleanup lease',
    () async {
      final validator = BlockingValidator();
      service = DownloadService(
        appSupportDirectory: support,
        spaceProbe: space,
        validator: validator,
        clientFactory: server.client,
      );
      late DownloadHandle<ResourceDownloadEvidence> handle;
      late Future<DownloadResult<ResourceDownloadEvidence>> firstCancel;
      late Future<DownloadResult<ResourceDownloadEvidence>> secondCancel;
      var armed = false;
      var injected = false;
      final requested = Completer<void>();
      await runZoned(
        () async {
          handle = service.start(spec);
          await validator.entered.future;
          armed = true;
          final pausing = service.pause(handle);
          validator.release.complete();
          await requested.future;
          expect((await firstCancel).state, DownloadState.cancelled);
          expect((await secondCancel).state, DownloadState.cancelled);
          await pausing;
        },
        zoneSpecification: ZoneSpecification(
          scheduleMicrotask: (self, parent, zone, callback) {
            // Intercept the public PAUSED transition before its worker has released
            // the lease. This schedules the race deterministically without sleeps.
            if (armed &&
                !injected &&
                service.progress(handle).state == DownloadState.paused) {
              injected = true;
              firstCancel = service.cancel(handle);
              secondCancel = service.cancel(handle);
              requested.complete();
            }
            parent.scheduleMicrotask(zone, callback);
          },
        ),
      );
      expect(await getPartial().exists(), isFalse);
      expect(await getMetadata().exists(), isFalse);
      expect(server.requests.length, 1);
      // Reuse a normal validator after cancellation; the request starts at zero.
      final fresh = DownloadService(
        appSupportDirectory: support,
        spaceProbe: space,
        validator: const ResourceDownloadValidator(),
        clientFactory: server.client,
      );
      expect((await fresh.start(spec).result).state, DownloadState.downloaded);
      expect(server.requests.last.range, isNull);
    },
  );

  test(
    'cancel still cleans staging if a pending validator rejects the bytes',
    () async {
      final validator = BlockingValidator()..reject = true;
      service = DownloadService(
        appSupportDirectory: support,
        spaceProbe: space,
        validator: validator,
        clientFactory: server.client,
      );
      final handle = service.start(spec);
      await validator.entered.future;
      final cancellation = service.cancel(handle);
      validator.release.complete();
      expect((await cancellation).state, DownloadState.cancelled);
      expect(await getPartial().exists(), isFalse);
      expect(await getMetadata().exists(), isFalse);
    },
  );

  for (final kind in [
    ResourceContractKind.llm,
    ResourceContractKind.ragPack,
    ResourceContractKind.ragEmbedding,
  ]) {
    test('${kind.dbKind} missing a catalog hash fails before HTTP', () async {
      final request = DownloadSpec(
        resourceId: spec.resourceId,
        artifactRevision: spec.artifactRevision,
        kind: kind,
        url: spec.url,
        destinationKey: spec.destinationKey,
        maxBytes: spec.maxBytes,
      );
      expect(
        (await service.start(request).result).failure!.code,
        DownloadFailureCode.invalidSpec,
      );
      expect(server.requests, isEmpty);
    });
  }

  for (final kind in [
    ResourceContractKind.llm,
    ResourceContractKind.ragPack,
    ResourceContractKind.ragEmbedding,
  ]) {
    test(
      '${kind.dbKind} uses the same transport and retains specialized checks',
      () async {
        // A header/opaque fixture is deliberately not a production model/pack.
        final bytes = kind == ResourceContractKind.llm
            ? [...ascii.encode('GGUF'), 3, 0, 0, 0, ...List<int>.filled(16, 0)]
            : ascii.encode('isolated opaque dataset artifact');
        final hash = await Sha256().hash(bytes);
        final request = DownloadSpec(
          resourceId: spec.resourceId,
          artifactRevision: spec.artifactRevision,
          kind: kind,
          url: spec.url,
          destinationKey: spec.destinationKey,
          maxBytes: bytes.length,
          expectedSize: bytes.length,
          expectedSha256: hash.bytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(),
        );
        server.respond = (request, _) =>
            DownloadTestServer.full(request, bytes);
        final result = await service.start(request).result;
        expect(result.state, DownloadState.downloaded);
        expect(await result.stagedFile!.readAsBytes(), bytes);
        expect(
          result.evidence!.format.remainingChecks,
          contains(switch (kind) {
            ResourceContractKind.llm => ResourceValidationCheck.modelLoadProven,
            ResourceContractKind.ragPack =>
              ResourceValidationCheck.validPackSchema,
            _ => ResourceValidationCheck.androidSampleQueryPassed,
          }),
        );
        if (kind != ResourceContractKind.llm) {
          expect(
            result.evidence!.format.status,
            FormatHeaderStatus.specializedValidatorRequired,
          );
        }
      },
    );
  }

  test(
    'PDF without catalog hash remains subject to PDF readability validation',
    () async {
      final request = DownloadSpec(
        resourceId: spec.resourceId,
        artifactRevision: spec.artifactRevision,
        kind: ResourceContractKind.pdf,
        url: spec.url,
        destinationKey: spec.destinationKey,
        expectedSize: spec.expectedSize,
        maxBytes: spec.maxBytes,
      );
      final result = await service.start(request).result;
      expect(result.state, DownloadState.downloaded);
      expect(result.evidence!.integrity.sha256Matched, isFalse);
      expect(
        result.evidence!.format.remainingChecks,
        contains(ResourceValidationCheck.pdfReadable),
      );
    },
  );
}
